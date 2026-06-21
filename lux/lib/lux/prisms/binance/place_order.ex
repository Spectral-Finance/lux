defmodule Lux.Prisms.Binance.PlaceOrder do
  @moduledoc """
  A prism for placing orders on Binance Spot or Futures.
  """

  use Lux.Prism,
    name: "Binance Place Order",
    description: "Places a trading order on Binance Spot or Futures network",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair symbol (e.g., BTCUSDT)"},
        side: %{type: :string, description: "BUY or SELL"},
        type: %{type: :string, description: "Order type (LIMIT, MARKET, etc.)"},
        quantity: %{type: :string, description: "Quantity to order"},
        price: %{type: :string, description: "Price for LIMIT orders (optional)"},
        time_in_force: %{
          type: :string,
          description: "Time in force (optional, required for LIMIT)"
        },
        network: %{type: :string, description: "Network: 'spot' or 'futures'", default: "spot"}
      },
      required: ["symbol", "side", "type", "quantity"]
    }

  alias Lux.Integrations.Binance.Client

  @impl true
  def handler(params, _ctx) do
    network =
      case Map.get(params, :network, "spot") do
        "spot" -> :spot
        "futures" -> :futures
        other -> String.to_existing_atom(other)
      end

    path =
      case network do
        :spot -> "/api/v3/order"
        :futures -> "/fapi/v1/order"
      end

    api_params =
      params
      |> Map.take([:symbol, :side, :type, :quantity, :price, :time_in_force])
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.into(%{})
      # Rename to match Binance API expected parameter names if needed (usually matches except case)
      # Assuming Binance expects uppercase
      |> Map.update(:side, nil, &String.upcase/1)
      |> Map.update(:type, nil, &String.upcase/1)
      |> Map.update(:symbol, nil, &String.upcase/1)

    case Client.request(:post, path, %{network: network, signed: true, params: api_params}) do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        {:error, inspect(error)}
    end
  end
end
