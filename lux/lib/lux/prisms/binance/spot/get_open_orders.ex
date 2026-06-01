defmodule Lux.Prisms.Binance.Spot.GetOpenOrders do
  @moduledoc """
  A prism for fetching open spot orders on Binance.

  ## Examples

      iex> GetOpenOrders.handler(%{symbol: "BTCUSDT"}, %{name: "Agent"})
      {:ok, %{
        orders: [
          %{order_id: 1, symbol: "BTCUSDT", side: "BUY", type: "LIMIT",
            price: "48000.00", orig_qty: "0.01", status: "NEW"}
        ],
        count: 1
      }}
  """

  use Lux.Prism,
    name: "Binance Get Open Orders",
    description: "Fetches all open spot orders for a symbol (or all symbols) on Binance",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Filter by symbol, e.g. BTCUSDT (optional)"},
        api_key: %{type: :string, description: "Binance API key"},
        secret_key: %{type: :string, description: "Binance secret key"}
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        orders: %{type: :array, description: "List of open orders"},
        count: %{type: :integer, description: "Number of open orders"}
      },
      required: ["orders", "count"]
    }

  alias Lux.Integrations.Binance.Client
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown"
    Logger.info("Agent #{agent_name} fetching open orders")

    query = %{}
    |> maybe_put(:symbol, params[:symbol])

    case Client.request(:get, "/api/v3/openOrders", %{
      signed: true,
      api_key: params[:api_key],
      secret_key: params[:secret_key],
      params: query
    }) do
      {:ok, orders} when is_list(orders) ->
        parsed = Enum.map(orders, &parse_order/1)
        {:ok, %{orders: parsed, count: length(parsed)}}

      {:error, err} ->
        {:error, "Failed to fetch open orders: #{inspect(err)}"}
    end
  end

  defp parse_order(o) do
    %{
      order_id: o["orderId"],
      symbol: o["symbol"],
      side: o["side"],
      type: o["type"],
      price: o["price"],
      orig_qty: o["origQty"],
      executed_qty: o["executedQty"],
      status: o["status"],
      time_in_force: o["timeInForce"],
      time: o["time"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
