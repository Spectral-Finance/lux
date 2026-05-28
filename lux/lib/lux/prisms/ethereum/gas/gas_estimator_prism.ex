defmodule Lux.Prisms.Ethereum.Gas.GasEstimatorPrism do
  @moduledoc """
  A prism that estimates the total gas cost for an Ethereum transaction.

  Uses the `eth_estimateGas` JSON-RPC method against a public Ethereum node,
  then fetches current gas prices to compute total cost in ETH and USD.

  ## Examples

      iex> Lux.Prisms.Ethereum.Gas.GasEstimatorPrism.handler(%{
      ...>   from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
      ...>   to: "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B",
      ...>   value_eth: 0.1,
      ...>   priority: :standard
      ...> }, %{})
      {:ok, %{
        estimated_gas: 21000,
        gas_price_gwei: 22.0,
        total_cost_eth: 0.000462,
        total_cost_usd: 1.39
      }}
  """

  use Lux.Prism,
    name: "Ethereum Gas Estimator",
    description: "Estimates gas cost for an Ethereum transaction including total ETH and USD cost",
    input_schema: %{
      type: :object,
      properties: %{
        from: %{
          type: :string,
          description: "Sender Ethereum address (0x-prefixed)"
        },
        to: %{
          type: :string,
          description: "Recipient Ethereum address (0x-prefixed)"
        },
        value_eth: %{
          type: :number,
          description: "Amount of ETH to send",
          default: 0
        },
        data: %{
          type: :string,
          description: "Hex-encoded transaction calldata (optional, for contract calls)"
        },
        priority: %{
          type: :string,
          enum: ["low", "standard", "fast", "urgent"],
          description: "Transaction priority, determines which gas price tier to use",
          default: "standard"
        }
      },
      required: ["from", "to"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        estimated_gas: %{
          type: :integer,
          description: "Estimated gas units required for the transaction"
        },
        gas_price_gwei: %{
          type: :number,
          description: "Recommended gas price in Gwei for the selected priority"
        },
        total_cost_eth: %{
          type: :number,
          description: "Total estimated transaction cost in ETH"
        },
        total_cost_usd: %{
          type: :number,
          description: "Total estimated transaction cost in USD (uses approximate ETH price)"
        }
      },
      required: ["estimated_gas", "gas_price_gwei", "total_cost_eth", "total_cost_usd"]
    }

  require Logger

  @rpc_url "https://eth.llamarpc.com"
  # Approximate ETH/USD price used for cost calculation; replace with a live feed in production.
  @eth_usd_price 3000.0

  @doc """
  Estimates the gas cost for a transaction.

  Accepts an optional `plug` key in `params` for test injection into Req.
  """
  def handler(params, _ctx) do
    from = Map.get(params, :from)
    to = Map.get(params, :to)
    value_eth = Map.get(params, :value_eth, 0)
    data = Map.get(params, :data, "0x")
    priority = params |> Map.get(:priority, :standard) |> normalize_priority()

    value_hex = eth_to_hex_wei(value_eth)

    tx_object =
      %{"from" => from, "to" => to, "value" => value_hex}
      |> maybe_add_data(data)

    req_opts = Application.get_env(:lux, __MODULE__, [])

    with {:ok, gas_units} <- estimate_gas(tx_object, req_opts),
         {:ok, gas_prices} <- fetch_gas_prices(req_opts) do
      gas_price_gwei = select_gas_price(gas_prices, priority)
      gas_price_wei = gas_price_gwei * 1.0e9
      total_cost_eth = gas_units * gas_price_wei / 1.0e18
      total_cost_usd = total_cost_eth * @eth_usd_price

      {:ok,
       %{
         estimated_gas: gas_units,
         gas_price_gwei: gas_price_gwei,
         total_cost_eth: Float.round(total_cost_eth, 8),
         total_cost_usd: Float.round(total_cost_usd, 4)
       }}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp estimate_gas(tx_object, req_opts) do
    body = %{
      jsonrpc: "2.0",
      method: "eth_estimateGas",
      params: [tx_object],
      id: 1
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

  defp fetch_gas_prices(req_opts) do
    body = %{
      jsonrpc: "2.0",
      method: "eth_gasPrice",
      params: [],
      id: 2
    }

    case Req.post(@rpc_url, [json: body] ++ req_opts) do
      {:ok, %{status: 200, body: %{"result" => hex}}} when is_binary(hex) ->
        base_gwei = hex_to_integer(hex) / 1.0e9

        {:ok,
         %{
           low: Float.round(base_gwei * 0.85, 2),
           standard: Float.round(base_gwei, 2),
           fast: Float.round(base_gwei * 1.25, 2),
           urgent: Float.round(base_gwei * 1.5, 2)
         }}

      {:ok, %{status: 200, body: %{"error" => %{"message" => msg}}}} ->
        {:error, "eth_gasPrice error: #{msg}"}

      {:ok, response} ->
        {:error, "Unexpected RPC response: #{inspect(response.body)}"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  defp select_gas_price(prices, :low), do: prices.low
  defp select_gas_price(prices, :standard), do: prices.standard
  defp select_gas_price(prices, :fast), do: prices.fast
  defp select_gas_price(prices, :urgent), do: prices.urgent
  defp select_gas_price(prices, _), do: prices.standard

  defp normalize_priority(priority) when is_atom(priority), do: priority

  defp normalize_priority(priority) when is_binary(priority) do
    case priority do
      "low" -> :low
      "fast" -> :fast
      "urgent" -> :urgent
      _ -> :standard
    end
  end

  defp eth_to_hex_wei(0), do: "0x0"
  defp eth_to_hex_wei(0.0), do: "0x0"

  defp eth_to_hex_wei(amount) do
    wei = trunc(amount * 1.0e18)
    "0x" <> Integer.to_string(wei, 16)
  end

  defp maybe_add_data(tx, nil), do: tx
  defp maybe_add_data(tx, ""), do: tx
  defp maybe_add_data(tx, "0x"), do: tx
  defp maybe_add_data(tx, data), do: Map.put(tx, "data", data)

  defp hex_to_integer("0x" <> hex), do: String.to_integer(hex, 16)
  defp hex_to_integer(hex) when is_binary(hex), do: String.to_integer(hex, 16)
end
