defmodule Lux.Prisms.Telegram.Analytics.CollectMetrics do
  @moduledoc """
  Collects Telegram update analytics without requiring a live Telegram API call.
  """

  use Lux.Prism,
    name: "Collect Telegram Analytics Metrics",
    description:
      "Aggregates Telegram Bot API updates into usage, engagement, error, and performance metrics",
    input_schema: %{
      type: :object,
      properties: %{
        updates: %{
          type: :array,
          description: "Raw Telegram Bot API updates or normalized event maps"
        },
        previous_user_ids: %{
          type: :array,
          description: "Optional previous-period user identifiers for retention calculations"
        },
        custom_metrics: %{
          type: :array,
          description: "Optional metric definitions with name, field, and value to count"
        }
      },
      required: ["updates"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        totals: %{type: :object, description: "Update totals grouped by event type"},
        engagement: %{
          type: :object,
          description: "Active chats, users, and derived engagement ratios"
        },
        commands: %{type: :object, description: "Command usage statistics"},
        errors: %{type: :object, description: "Error counts and rate"},
        performance: %{type: :object, description: "Latency summary"},
        custom_metrics: %{type: :array, description: "User-defined metric counts"},
        visualizations: %{type: :object, description: "Chart-ready report payloads"}
      },
      required: ["totals", "engagement", "errors", "performance", "visualizations"]
    }

  alias Lux.Integrations.Telegram.Analytics

  @impl true
  def handler(params, _agent) do
    updates = fetch_param(params, :updates) || fetch_param(params, :events) || []

    opts = [
      previous_user_ids: fetch_param(params, :previous_user_ids) || [],
      custom_metrics: fetch_param(params, :custom_metrics) || [],
      generated_at: fetch_param(params, :generated_at)
    ]

    {:ok, Analytics.report(updates, opts)}
  end

  defp fetch_param(params, key) when is_map(params),
    do:
      if(Map.has_key?(params, key),
        do: Map.get(params, key),
        else: Map.get(params, Atom.to_string(key))
      )
end
