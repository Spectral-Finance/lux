defmodule Lux.Prisms.YouTube.FetchCommentsPrism do
  use Lux.Prism,
    name: "Fetch YouTube Comments",
    description: "Fetches comments using the CommentsLens",
    input_schema: %{
      type: :object,
      properties: %{
        videoId: %{type: :string}
      },
      required: ["videoId"]
    }

  def handler(%{videoId: videoId}, _ctx) do
    Lux.Lenses.YouTube.CommentsLens.focus(%{videoId: videoId})
  end
end
