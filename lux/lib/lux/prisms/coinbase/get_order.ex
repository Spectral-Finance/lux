defmodule Lux.Prisms.Coinbase.GetOrder do
  @moduledoc """
  A prism for fetching a single order's details from Coinbase Advanced Trade.

  ## Examples

      iex> Lux.Prisms.Coinbase.GetOrder.handler(%{
      ...>   order_id: "abc-123-def-456"
      ...> }, %{agent: %{name: "TradingAgent"}})
      {:ok, %{
        order_id: "abc-123-def-456",
        product_id: "BTC-USD",
        side: "BUY",
        status: "FILLED",
        order_type: "LIMIT",
        filled_size: "0.001",
        average_filled_price: "43250.00",
        total_fees: "0.26"
      }}
  """

  use Lux.Prism,
    name: "Coinbase Get Order",
    description: "Fetches details of a specific order from Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        order_id: %{
          type: :string,
          description: "The order ID to look up"
        }
      },
      required: ["order_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        order_id: %{type: :string},
        product_id: %{type: :string},
        side: %{type: :string},
        status: %{type: :string},
        order_type: %{type: :string},
        created_time: %{type: :string},
        filled_size: %{type: :string},
        average_filled_price: %{type: :string},
        total_fees: %{type: :string},
        order_configuration: %{type: :object}
      },
      required: ["order_id", "status"]
    }

  alias Lux.Integrations.Coinbase.Client

  require Logger

  def handler(params, _ctx) do
    with {:ok, order_id} <- validate_param(params, :order_id) do
      request_opts =
        if params[:plug], do: %{plug: params[:plug]}, else: %{}

      case Client.request(:get, "/orders/historical/#{order_id}", request_opts) do
        {:ok, %{"order" => order}} ->
          {:ok, %{
            order_id: order["order_id"],
            product_id: order["product_id"],
            side: order["side"],
            status: order["status"],
            order_type: order["order_type"],
            created_time: order["created_time"],
            completion_percentage: order["completion_percentage"],
            filled_size: order["filled_size"],
            filled_value: order["filled_value"],
            average_filled_price: order["average_filled_price"],
            total_fees: order["total_fees"],
            total_value_after_fees: order["total_value_after_fees"],
            order_configuration: order["order_configuration"],
            settled: order["settled"],
            cancel_message: order["cancel_message"]
          }}

        {:error, error} ->
          Logger.error("Failed to get order #{order_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
