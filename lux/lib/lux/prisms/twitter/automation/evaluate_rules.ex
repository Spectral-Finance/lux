defmodule Lux.Prisms.Twitter.Automation.EvaluateRules do
  @moduledoc """
  Evaluates Twitter/X engagement rules and returns safe action plans.
  """

  use Lux.Prism,
    name: "Evaluate Twitter Engagement Rules",
    description:
      "Matches Twitter/X events against engagement rules for replies, reposts, follows, likes, and DMs",
    input_schema: %{
      type: :object,
      properties: %{
        events: %{type: :array, description: "Mention, reply, follow, hashtag, or DM events"},
        rules: %{type: :array, description: "Engagement rules with conditions and actions"},
        self_author_ids: %{type: :array, description: "Account ids to suppress self-engagement"}
      },
      required: ["events", "rules"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        actions: %{type: :array},
        summary: %{type: :object}
      },
      required: ["actions", "summary"]
    }

  alias Lux.Integrations.Twitter.Automation

  @impl true
  def handler(params, _agent) do
    events = fetch_param(params, :events) || []
    rules = fetch_param(params, :rules) || []
    opts = %{self_author_ids: fetch_param(params, :self_author_ids) || []}

    {:ok, Automation.evaluate_rules(events, rules, opts)}
  end

  defp fetch_param(params, key) when is_map(params),
    do:
      if(Map.has_key?(params, key),
        do: Map.get(params, key),
        else: Map.get(params, Atom.to_string(key))
      )
end
