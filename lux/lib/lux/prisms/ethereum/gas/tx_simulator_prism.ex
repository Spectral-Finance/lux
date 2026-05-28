defmodule Lux.Prisms.Ethereum.Gas.TxSimulatorPrism do
  @moduledoc """
  A prism that simulates an Ethereum transaction using `eth_call` without
  broadcasting it to the network.

  This is useful for:
  * Pre-flight validation — check whether a transaction will revert before
    spending gas.
  * Gas profiling — compare actual simulated gas with `eth_estimateGas`.
  * Return value inspection — decode the raw return data for contract calls.

  The simulation is performed against the state at the specified block tag
  (default `:latest`).

  ## Examples

      iex> Lux.Prisms.Ethereum.Gas.TxSimulatorPrism.handler(%{
      ...>   from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      ...>   to: "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B",
      ...>   value: 0,
      ...>   data: "0x",
      ...>   block: :latest
      ...> }, %{})
      {:ok, %{success: true, gas_used: 21000, return_data: "0x"}}
  """

  use Lux.Prism,
    name: "Ethereum Transaction Simulator",
    description: "Simulates a transaction with eth_call to check success, gas, and return data",
    input_schema: %{
      type: :object,
      properties: %{
        from: %{
          type: :string,
          description: "Sender Ethereum address (0x-prefixed)"
        },
        to: %{
          type: :string,
          description: "Recipient or contract address (0x-prefixed)"
        },
        value: %{
          type: :number,
          description: "ETH value to send with the call",
          default: 0
        },
        data: %{
          type: :string,
          description: "Hex-encoded calldata (0x for plain ETH transfers)",
          default: "0x"
        },
        block: %{
          type: :string,
          description: "Block tag to simulate against (latest, pending, earliest, or hex number)",
          default: "latest"
        }
      },
      required: ["from", "to"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the simulated transaction would succeed"
        },
        gas_used: %{
          type: :integer,
          description: "Estimated gas units consumed by the call"
        },
        return_data: %{
          type: :string,
          description: "Hex-encoded return data from the call"
        }
      },
      required: ["success", "gas_used", "return_data"]
    }

  require Logger

  @rpc_url "https://eth.llamarpc.com"

  @doc """
  Simulates the transaction and returns execution results.
  """
  def handler(params, _ctx) do
    from = Map.get(params, :from)
    to = Map.get(params, :to)
    value = Map.get(params, :value, 0)
    data = Map.get(params, :data, "0x")
    block = params |> Map.get(:block, :latest) |> normalize_block()

    value_hex = eth_to_hex_wei(value)

    tx_object = %{
      "from" => from,
      "to" => to,
      "value" => value_hex,
      "data" => data
    }

    req_opts = Application.get_env(:lux, __MODULE__, [])

    with {:ok, return_data} <- run_eth_call(tx_object, block, req_opts),
         {:ok, gas_used} <- estimate_gas(tx_object, req_opts) do
      {:ok,
       %{
         success: true,
         gas_used: gas_used,
         return_data: return_data
       }}
    else
      {:error, reason} when is_binary(reason) ->
        if String.contains?(reason, "revert") or String.contains?(reason, "execution reverted") do
          {:error, "Transaction would revert: #{reason}"}
        else
          {:error, reason}
        end

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp run_eth_call(tx_object, block, req_opts) do
    body = %{
      jsonrpc: "2.0",
      method: "eth_call",
      params: [tx_object, block],
      id: 1
    }

    case Req.post(@rpc_url, [json: body] ++ req_opts) do
      {:ok, %{status: 200, body: %{"result" => result}}} when is_binary(result) ->
        {:ok, result}

      {:ok, %{status: 200, body: %{"error" => %{"message" => msg}}}} ->
        {:error, msg}

      {:ok, response} ->
        {:error, "Unexpected RPC response: #{inspect(response.body)}"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  defp estimate_gas(tx_object, req_opts) do
    body = %{
      jsonrpc: "2.0",
      method: "eth_estimateGas",
      params: [tx_object],
      id: 2
    }

    case Req.post(@rpc_url, [json: body] ++ req_opts) do
      {:ok, %{status: 200, body: %{"result" => hex}}} when is_binary(hex) ->
        {:ok, hex_to_integer(hex)}

      {:ok, %{status: 200, body: %{"error" => %{"message" => msg}}}} ->
        {:error, "eth_estimateGas error: #{msg}"}

      {:ok, response} ->
        {:error, "Unexpected RPC response: #{inspect(response.body)}"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  defp normalize_block(:latest), do: "latest"
  defp normalize_block(:pending), do: "pending"
  defp normalize_block(:earliest), do: "earliest"
  defp normalize_block("latest"), do: "latest"
  defp normalize_block("pending"), do: "pending"
  defp normalize_block("earliest"), do: "earliest"
  defp normalize_block(block) when is_binary(block), do: block
  defp normalize_block(block) when is_integer(block), do: "0x" <> Integer.to_string(block, 16)
  defp normalize_block(_), do: "latest"

  defp eth_to_hex_wei(0), do: "0x0"
  defp eth_to_hex_wei(0.0), do: "0x0"

  defp eth_to_hex_wei(amount) when is_number(amount) do
    wei = trunc(amount * 1.0e18)
    "0x" <> Integer.to_string(wei, 16)
  end

  defp hex_to_integer("0x" <> hex), do: String.to_integer(hex, 16)
  defp hex_to_integer(hex) when is_binary(hex), do: String.to_integer(hex, 16)
end
