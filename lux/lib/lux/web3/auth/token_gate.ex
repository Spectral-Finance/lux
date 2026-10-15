defmodule Lux.Web3.Auth.TokenGate do
  @moduledoc """
  Token-gated and NFT-gated access control policy evaluator across EVM chains.

  Supports native token balance thresholds (`eth_getBalance`) as well as ERC-20
  and ERC-721 contract `balanceOf(address)` (`0x70a08231`) requirements.
  """

  @default_endpoints %{
    ethereum: "https://eth.llamarpc.com",
    polygon: "https://polygon-rpc.com",
    bsc: "https://bsc-dataseed.binance.org",
    arbitrum: "https://arb1.arbitrum.io/rpc",
    optimism: "https://mainnet.optimism.io",
    base: "https://mainnet.base.org"
  }

  @type rule :: %{
          optional(:type) => :native | :erc20 | :erc721,
          optional(:chain) => atom(),
          optional(:contract_address) => String.t(),
          min_balance: non_neg_integer()
        }

  @doc """
  Checks whether `address` satisfies the token-gate rule (`:native`, `:erc20`, or `:erc721`).
  """
  @spec check_access(String.t(), rule() | map(), keyword()) ::
          {:ok, %{granted: boolean(), balance: non_neg_integer(), min_balance: non_neg_integer()}}
          | {:error, term()}
  def check_access(address, rule, opts \\ []) when is_binary(address) and is_map(rule) do
    chain = Map.get(rule, :chain, :ethereum)
    min_balance = Map.get(rule, :min_balance, 1)
    default_type = if Map.get(rule, :contract_address), do: :erc20, else: :native
    gate_type = Map.get(rule, :type, default_type)

    with {:ok, balance} <- fetch_balance(gate_type, chain, address, rule, opts) do
      {:ok,
       %{
         granted: balance >= min_balance,
         balance: balance,
         min_balance: min_balance
       }}
    end
  end

  defp fetch_balance(:native, chain, address, _rule, opts) do
    with {:ok, hex} <- rpc_call(chain, "eth_getBalance", [address, "latest"], opts) do
      {:ok, hex_to_int(hex)}
    end
  end

  defp fetch_balance(type, chain, address, rule, opts) when type in [:erc20, :erc721] do
    contract = Map.get(rule, :contract_address)
    clean_addr =
      address
      |> String.trim_leading("0x")
      |> String.downcase()
      |> String.pad_leading(64, "0")
    call_data = "0x70a08231" <> clean_addr
    call_obj = %{"to" => contract, "data" => call_data}

    with {:ok, hex} <- rpc_call(chain, "eth_call", [call_obj, "latest"], opts) do
      {:ok, hex_to_int(hex)}
    end
  end

  defp rpc_call(chain, method, params, opts) do
    default_url = Map.get(@default_endpoints, chain, "https://eth.llamarpc.com")
    url = Keyword.get(opts, :rpc_url, default_url)

    payload = %{
      "jsonrpc" => "2.0",
      "id" => System.unique_integer([:positive]),
      "method" => method,
      "params" => params
    }

    req_opts =
      [
        url: url,
        json: payload,
        headers: [{"Content-Type", "application/json"}]
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    case Req.post(Req.new(req_opts)) do
      {:ok, %{status: 200, body: %{"result" => result}}} ->
        {:ok, result}

      {:ok, %{status: 200, body: %{"error" => err}}} ->
        {:error, {:rpc_error, err}}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp hex_to_int("0x" <> hex) when byte_size(hex) > 0 do
    case Integer.parse(hex, 16) do
      {num, ""} when num >= 0 -> num
      _ -> 0
    end
  end

  defp hex_to_int(val) when is_integer(val) and val >= 0, do: val
  defp hex_to_int(_), do: 0
end
