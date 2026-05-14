defmodule Lux.Prisms.Twitter.Automation.ScheduleContent do
  @moduledoc """
  Builds a deterministic Twitter/X content schedule from draft posts.
  """

  use Lux.Prism,
    name: "Schedule Twitter Content",
    description:
      "Creates a prioritized Twitter/X content calendar with spacing, per-day limits, and safety warnings",
    input_schema: %{
      type: :object,
      properties: %{
        items: %{type: :array, description: "Draft tweet content items"},
        start_at: %{type: :string, description: "ISO8601 start time"},
        interval_minutes: %{
          type: :integer,
          description: "Minimum spacing between scheduled posts"
        },
        per_day_limit: %{type: :integer, description: "Maximum scheduled posts per UTC day"}
      },
      required: ["items"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        scheduled: %{type: :array},
        calendar: %{type: :object},
        summary: %{type: :object}
      },
      required: ["scheduled", "calendar", "summary"]
    }

  alias Lux.Integrations.Twitter.Automation

  @impl true
  def handler(params, _agent) do
    items = fetch_param(params, :items) || fetch_param(params, :content) || []

    opts =
      params
      |> Map.take([:start_at, :interval_minutes, :per_day_limit, :timezone])
      |> Map.merge(
        Map.take(params, ["start_at", "interval_minutes", "per_day_limit", "timezone"])
      )

    {:ok, Automation.schedule_content(items, opts)}
  end

  defp fetch_param(params, key) when is_map(params),
    do:
      if(Map.has_key?(params, key),
        do: Map.get(params, key),
        else: Map.get(params, Atom.to_string(key))
      )
end
