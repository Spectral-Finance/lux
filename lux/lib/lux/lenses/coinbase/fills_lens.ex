defmodule Lux.Lenses.Coinbase.FillsLens do
  @moduledoc """
  A lens for fetching order fills from Coinbase.

  Returns a list of fills (executed trades) with filtering options.

  ## Examples

      iex> Lux.Lenses.Coinbase.FillsLens.focus(%{product_id: "BTC-USD"})
      {:ok, %{fills: [
        %{
          entry_id: "abc-123",
          trade_id: "trade-456",
          order_id: "order-789",
          product_id: "BTC-USD",
          side: "BUY",
          price: "43250.00",
          size: "0.001",
          commission: "0.26"
        }
      ]}}
  """

  alias Lux.Integrations.Coinbase

  use Lux.Lens,
    name: "Coinbase Fills",
    description: "Fetches order fills from Coinbase Advanced Trade API",
    url: "https://api.coinbase.com/api/v3/brokerage/orders/historical/fills",
    method: :get,
    headers: Coinbase.headers(),
    auth: Coinbase.auth(),
    schema: %{
      type: :object,
      properties: %{
        order_id: %{
          type: :string,
          description: "Filter by order ID"
        },
        product_id: %{
          type: :string,
          description: "Filter by product ID (e.g., BTC-USD)"
        },
        start_sequence_timestamp: %{
          type: :string,
          description: "Start time filter (ISO 8601)"
        },
        end_sequence_timestamp: %{
          type: :string,
          description: "End time filter (ISO 8601)"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of fills to return"
        },
        cursor: %{
          type: :string,
          description: "Pagination cursor"
        }
      }
    }

  def after_focus(%{"fills" => fills} = response) do
    formatted =
      Enum.map(fills, fn fill ->
        %{
          entry_id: fill["entry_id"],
          trade_id: fill["trade_id"],
          order_id: fill["order_id"],
          trade_time: fill["trade_time"],
          trade_type: fill["trade_type"],
          price: fill["price"],
          size: fill["size"],
          commission: fill["commission"],
          product_id: fill["product_id"],
          side: fill["side"],
          sequence_timestamp: fill["sequence_timestamp"],
          liquidity_indicator: fill["liquidity_indicator"],
          size_in_quote: fill["size_in_quote"]
        }
      end)

    result = %{fills: formatted}

    result =
      if response["cursor"], do: Map.put(result, :cursor, response["cursor"]), else: result

    {:ok, result}
  end

  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:ok, other}
end
