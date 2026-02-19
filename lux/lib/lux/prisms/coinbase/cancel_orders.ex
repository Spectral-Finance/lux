defmodule Lux.Prisms.Coinbase.CancelOrders do
  @moduledoc """
  A prism for cancelling one or more orders on Coinbase Advanced Trade.

  Supports batch cancellation of orders by their order IDs.

  ## Examples

      # Cancel a single order
      iex> Lux.Prisms.Coinbase.CancelOrders.handler(%{
      ...>   order_ids: ["order-abc-123"]
      ...> }, %{agent: %{name: "TradingAgent"}})
      {:ok, %{
        results: [%{order_id: "order-abc-123", success: true}]
      }}

      # Cancel multiple orders
      iex> Lux.Prisms.Coinbase.CancelOrders.handler(%{
      ...>   order_ids: ["order-1", "order-2", "order-3"]
      ...> }, %{agent: %{name: "TradingAgent"}})
      {:ok, %{
        results: [
          %{order_id: "order-1", success: true},
          %{order_id: "order-2", success: true},
          %{order_id: "order-3", success: false, failure_reason: "UNKNOWN_ORDER"}
        ]
      }}
  """

  use Lux.Prism,
    name: "Coinbase Cancel Orders",
    description: "Cancels one or more orders on Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        order_ids: %{
          type: :array,
          description: "List of order IDs to cancel",
          items: %{type: :string}
        }
      },
      required: ["order_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        results: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              order_id: %{type: :string},
              success: %{type: :boolean},
              failure_reason: %{type: :string}
            }
          }
        }
      },
      required: ["results"]
    }

  alias Lux.Integrations.Coinbase.Client

  require Logger

  def handler(params, ctx) do
    agent_name = get_in(ctx, [:agent, :name]) || ctx[:name] || "Unknown Agent"

    with {:ok, order_ids} <- validate_order_ids(params) do
      body = %{order_ids: order_ids}

      Logger.info(
        "Agent #{agent_name} cancelling #{length(order_ids)} order(s)"
      )

      request_opts =
        if params[:plug], do: %{json: body, plug: params[:plug]}, else: %{json: body}

      case Client.request(:post, "/orders/batch_cancel", request_opts) do
        {:ok, %{"results" => results}} ->
          formatted =
            Enum.map(results, fn result ->
              base = %{
                order_id: result["order_id"],
                success: result["success"]
              }

              if result["failure_reason"] do
                Map.put(base, :failure_reason, result["failure_reason"])
              else
                base
              end
            end)

          Logger.info("Cancel results: #{length(formatted)} order(s) processed")
          {:ok, %{results: formatted}}

        {:error, error} ->
          Logger.error("Failed to cancel orders: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_order_ids(params) do
    case Map.fetch(params, :order_ids) do
      {:ok, ids} when is_list(ids) and length(ids) > 0 ->
        if Enum.all?(ids, &is_binary/1) do
          {:ok, ids}
        else
          {:error, "All order_ids must be strings"}
        end

      {:ok, _} ->
        {:error, "order_ids must be a non-empty list"}

      :error ->
        {:error, "Missing order_ids"}
    end
  end
end
