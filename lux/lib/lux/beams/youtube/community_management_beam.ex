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
    step(:fetch_comments, Lux.Prisms.YouTube.FetchCommentsPrism, %{videoId: :videoId})
    step(:process_comments, Lux.Prisms.YouTube.ProcessCommentsPrism, %{comments_data: {:ref, "fetch_comments"}})
  end
end
