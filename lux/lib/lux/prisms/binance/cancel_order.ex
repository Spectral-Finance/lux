defmodule Lux.Prisms.Binance.CancelOrder do
  @moduledoc """
  A prism for cancelling orders on Binance Spot or Futures.
  """

  use Lux.Prism,
    name: "Binance Cancel Order",
    description: "Cancels an active trading order on Binance Spot or Futures network",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair symbol (e.g., BTCUSDT)"},
        order_id: %{type: :string, description: "Order ID to cancel"},
        network: %{type: :string, description: "Network: 'spot' or 'futures'", default: "spot"}
      },
      required: ["symbol", "order_id"]
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

    api_params = %{
      symbol: String.upcase(params.symbol),
      orderId: params.order_id
    }

    case Client.request(:delete, path, %{network: network, signed: true, params: api_params}) do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        {:error, inspect(error)}
    end
  end
end
