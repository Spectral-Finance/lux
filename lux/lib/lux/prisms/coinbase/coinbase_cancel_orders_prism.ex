defmodule Lux.Prisms.Coinbase.CancelOrdersPrism do
  @moduledoc """
  A prism for cancelling one or more orders on Coinbase Advanced Trade.

  ## Examples

      iex> Lux.Prisms.Coinbase.CancelOrdersPrism.handler(%{
      ...>   order_ids: ["abc123", "def456"]
      ...> }, %{name: "Agent"})
      {:ok, %{
        cancelled: ["abc123"],
        failed: ["def456"]
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
          items: %{type: :string},
          minItems: 1,
          maxItems: 100
        }
      },
      required: ["order_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        cancelled: %{type: :array, items: %{type: :string}, description: "Successfully cancelled order IDs"},
        failed: %{type: :array, items: %{type: :string}, description: "Order IDs that failed to cancel"}
      },
      required: ["cancelled", "failed"]
    }

  alias Lux.Integrations.Coinbase
  require Logger

  def handler(%{order_ids: order_ids}, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} cancelling #{length(order_ids)} orders")

    case Coinbase.post("/api/v3/brokerage/orders/batch_cancel", %{order_ids: order_ids}) do
      {:ok, %{"results" => results}} ->
        {cancelled, failed} = Enum.split_with(results, fn r ->
          r["success"] == true
        end)
        result = %{
          cancelled: Enum.map(cancelled, & &1["order_id"]),
          failed: Enum.map(failed, & &1["order_id"])
        }
        Logger.info("Cancelled #{length(cancelled)} orders, #{length(failed)} failed")
        {:ok, result}

      {:error, {status, body}} ->
        msg = get_in(body, ["message"]) || inspect(body)
        Logger.error("Coinbase cancel orders error: #{status} - #{msg}")
        {:error, {status, msg}}

      {:error, reason} ->
        Logger.error("Cancel orders request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
