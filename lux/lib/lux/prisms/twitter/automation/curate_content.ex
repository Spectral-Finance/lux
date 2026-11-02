defmodule Lux.Prisms.Twitter.Automation.CurateContent do
  @moduledoc """
  A prism for discovering, scoring, and generating proposals for top-performing curated tweets.
  """

  use Lux.Prism,
    name: "Curate Twitter Content",
    description: "Evaluates and ranks candidate tweets based on engagement, authority, and virality metrics",
    input_schema: %{
      type: :object,
      properties: %{
        candidates: %{type: :array, description: "List of candidate tweet objects"},
        seen_ids: %{type: :array, description: "List of already curated tweet IDs for deduplication"},
        min_score: %{type: :number, description: "Minimum quality threshold score"}
      },
      required: ["candidates"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        ranked_items: %{type: :array},
        count: %{type: :integer}
      },
      required: ["ranked_items", "count"]
    }

  alias Lux.Integrations.Twitter.Automation.ContentCurator

  def handler(params, _agent) when is_map(params) do
    candidates = Map.get(params, :candidates) || Map.get(params, "candidates", [])
    seen_ids = Map.get(params, :seen_ids) || Map.get(params, "seen_ids", [])
    min_score = Map.get(params, :min_score) || Map.get(params, "min_score", 10.0)

    ranked = ContentCurator.rank_content(candidates, seen_ids, %{min_score: min_score})

    {:ok,
     %{
       ranked_items: ranked,
       count: length(ranked)
     }}
  end

  def handler(_, _), do: {:error, "Invalid parameters: expected candidates list"}
end
