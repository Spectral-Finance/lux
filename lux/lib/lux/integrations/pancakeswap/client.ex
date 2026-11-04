defmodule Lux.Integrations.PancakeSwap.Client do
  @moduledoc """
  Minimal JSON-RPC client used by the PancakeSwap prisms to read chain state.

  Requests are made with `Req`. Tests can inject a plug through application config:

      Application.put_env(:lux, Lux.Integrations.PancakeSwap.Client,
        plug: {Req.Test, MyMock}
      )

  ## Options

    * `:rpc_url` - overrides the default public RPC endpoint of the chain
  """

  alias Lux.Integrations.PancakeSwap
  alias Lux.Integrations.PancakeSwap.Codec

  @type chain :: PancakeSwap.chain()
  @type result :: {:ok, term()} | {:error, term()}

  @doc """
  Sends a JSON-RPC 2.0 request and returns the `result` field.

  Errors are `{:rpc_error, code, message}`, `{:http_error, status, body}` or the
  transport error returned by Req.
  """
  @spec rpc(chain(), String.t(), list(), keyword()) :: result()
  def rpc(chain, method, params, opts \\ []) do
    url = opts[:rpc_url] || chain.rpc_url

    [
      method: :post,
      url: url,
      headers: [{"Content-Type", "application/json"}],
      json: %{jsonrpc: "2.0", id: 1, method: method, params: params},
      retry: false
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  @doc """
  Executes a read-only contract call and decodes the result.

  `signature` is the canonical function signature (for example
  `"balanceOf(address)"`), `args` the call arguments and `output_types` the ABI types
  of the return values. Returns the decoded values as a list.
  """
  @spec eth_call(chain(), String.t(), String.t(), [term()], [String.t()], keyword()) ::
          {:ok, [term()]} | {:error, term()}
  def eth_call(chain, to, signature, args, output_types, opts \\ []) do
    data = signature |> Codec.encode_call(args) |> Codec.to_hex()

    with {:ok, hex} <- rpc(chain, "eth_call", [%{to: to, data: data}, "latest"], opts) do
      Codec.decode(output_types, hex)
    end
  rescue
    error in ArgumentError -> {:error, Exception.message(error)}
  end

  @doc """
  Returns the ERC-20 allowance `owner` granted to `spender` for `token`.
  """
  @spec allowance(chain(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def allowance(chain, token, owner, spender, opts \\ []) do
    with {:ok, [amount]} <-
           eth_call(
             chain,
             token,
             "allowance(address,address)",
             [owner, spender],
             ["uint256"],
             opts
           ) do
      {:ok, amount}
    end
  end

  @doc """
  Returns the current gas price of the chain in wei.
  """
  @spec gas_price(chain(), keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def gas_price(chain, opts \\ []) do
    with {:ok, "0x" <> hex} <- rpc(chain, "eth_gasPrice", [], opts),
         {value, ""} <- Integer.parse(hex, 16) do
      {:ok, value}
    else
      {:error, _reason} = error -> error
      {:ok, other} -> {:error, {:invalid_response, other}}
      _ -> {:error, :invalid_response}
    end
  end

  defp handle_response({:ok, %{status: 200, body: body}}) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> handle_body(decoded)
      {:error, _} -> {:error, {:http_error, 200, body}}
    end
  end

  defp handle_response({:ok, %{status: 200, body: body}}), do: handle_body(body)

  defp handle_response({:ok, %{status: status, body: body}}),
    do: {:error, {:http_error, status, body}}

  defp handle_response({:error, error}), do: {:error, error}

  defp handle_body(%{"error" => %{"code" => code, "message" => message}}),
    do: {:error, {:rpc_error, code, message}}

  defp handle_body(%{"result" => result}), do: {:ok, result}
  defp handle_body(body), do: {:error, {:http_error, 200, body}}
end
