defmodule Lux.Beams.YouTube.CommunityManagementBeam do
  use Lux.Beam,
    name: "YouTube Community Management",
    description: "Fetches comments, analyzes sentiment, and moderates or replies",
    input_schema: %{
      type: :object,
      properties: %{
        videoId: %{type: :string}
      },
      required: ["videoId"]
    }

  sequence do
    step(:fetch_comments, Lux.Prisms.YouTube.FetchCommentsPrism, %{videoId: [:input, :videoId]})
    step(:process_comments, Lux.Prisms.YouTube.ProcessCommentsPrism, %{comments_data: [:steps, :fetch_comments, :result]})
  end
end
