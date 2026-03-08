defmodule Lux.Prisms.Coinbase.CancelOrder do
  @moduledoc """
  Prism for cancelling orders on Coinbase.
  """

  use Lux.Prism,
    name: "Cancel Coinbase Order",
    description: "Cancels one or more orders on Coinbase",
    input_schema: %{
      type: :object,
      properties: %{
        order_ids: %{type: :array, items: %{type: :string}, description: "Order IDs to cancel"}
      },
      required: ["order_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{type: :boolean},
        results: %{type: :array, items: %{type: :object, properties: %{order_id: %{type: :string}, success: %{type: :boolean}}}}
      },
      required: ["success"]
    }

  alias Lux.Integrations.Coinbase.Client
  require Logger

  def handler(params, agent) do
    order_ids = params[:order_ids] || params["order_ids"] || []

    if Enum.empty?(order_ids) do
      {:error, "No order IDs provided"}
    else
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} cancelling #{length(order_ids)} order(s)")

      case Client.request(:post, "/orders/batch_cancel", %{json: %{order_ids: order_ids}}) do
        {:ok, %{"results" => results}} ->
          formatted = Enum.map(results, fn r -> %{order_id: r["order_id"], success: r["success"]} end)
          {:ok, %{success: Enum.all?(formatted, & &1.success), results: formatted}}
        {:error, error} -> {:error, error}
      end
    end
  end
end
