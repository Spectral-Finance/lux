defmodule Lux.Prisms.Twitter.Automation.ManageQueue do
  @moduledoc """
  Converts Twitter/X action plans into a rate-limited queue.
  """

  use Lux.Prism,
    name: "Manage Twitter Automation Queue",
    description:
      "Deduplicates, prioritizes, and rate-limits Twitter/X automation actions with review gates for sensitive actions",
    input_schema: %{
      type: :object,
      properties: %{
        actions: %{
          type: :array,
          description: "Action plans from engagement rules or another planner"
        },
        now: %{type: :string, description: "ISO8601 queue start time"},
        per_window_limit: %{type: :integer, description: "Maximum actions per queue window"},
        window_minutes: %{type: :integer, description: "Queue window length in minutes"}
      },
      required: ["actions"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        queued: %{type: :array},
        summary: %{type: :object}
      },
      required: ["queued", "summary"]
    }

  alias Lux.Integrations.Twitter.Automation

  @impl true
  def handler(params, _agent) do
    actions = fetch_param(params, :actions) || []

    opts =
      params
      |> Map.take([:now, :per_window_limit, :window_minutes, :review_required_actions])
      |> Map.merge(
        Map.take(params, ["now", "per_window_limit", "window_minutes", "review_required_actions"])
      )

    {:ok, Automation.queue_actions(actions, opts)}
  end

  defp fetch_param(params, key) when is_map(params),
    do:
      if(Map.has_key?(params, key),
        do: Map.get(params, key),
        else: Map.get(params, Atom.to_string(key))
      )
end
