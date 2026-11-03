defmodule Lux.Prisms.Coinbase.OrderPrism do
  @moduledoc """
  Validates and prepares an order for Coinbase Advanced Trade v3 execution.
  """

  use Lux.Prism,
    name: "Coinbase Order Prism",
    description: "Validates order parameters and generates payload for Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{type: :string, description: "Market symbol (e.g. BTC-USD)"},
        side: %{type: :string, description: "BUY or SELL"},
        type: %{type: :string, default: "LIMIT"},
        base_size: %{type: :number, description: "Base token order quantity"},
        limit_price: %{type: :number, description: "Limit price in quote currency"},
        quote_size: %{type: :number, description: "Quote amount for market orders"}
      },
      required: ["product_id", "side"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        client_order_id: %{type: :string},
        product_id: %{type: :string},
        side: %{type: :string},
        status: %{type: :string}
      },
      required: ["client_order_id", "product_id", "side", "status"]
    }

  alias Lux.Integrations.Coinbase.OrderManager

  def handler(input, _ctx) do
    case OrderManager.build_order(input) do
      {:ok, payload} ->
        {:ok,
         %{
           client_order_id: payload["client_order_id"],
           product_id: payload["product_id"],
           side: payload["side"],
           order_configuration: payload["order_configuration"],
           status: "validated"
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
