defmodule Lux.Prisms.YouTube.ProcessCommentsPrism do
  use Lux.Prism,
    name: "Process YouTube Comments",
    description: "Iterates through comments and moderates/replies based on sentiment",
    input_schema: %{
      type: :object,
      properties: %{
        comments_data: %{type: :object}
      },
      required: ["comments_data"]
    }

  def handler(%{comments_data: %{"items" => comments}}, _ctx) do
    results = Enum.map(comments, fn item ->
      comment_id = item["id"]
      text = item["snippet"]["topLevelComment"]["snippet"]["textOriginal"] || item["snippet"]["topLevelComment"]["snippet"]["textDisplay"]

      # Run Sentiment Beam
      {:ok, %{sentiment: sentiment}, _log} = Lux.Beams.YouTube.SentimentAnalysisBeam.run(%{text: text})

      action_result =
        case sentiment do
          :spam ->
            Lux.Prisms.YouTube.ModerateCommentPrism.run(%{id: comment_id, moderationStatus: "rejected"})
          :positive ->
            Lux.Prisms.YouTube.ReplyToCommentPrism.run(%{parentId: comment_id, textOriginal: "Thanks for the positive feedback!"})
          _ ->
            {:ok, :no_action}
        end

      %{id: comment_id, sentiment: sentiment, action: action_result}
    end)

    {:ok, results}
  end

  def handler(args, _ctx) do
    IO.inspect(args, label: "ProcessCommentsPrism fallback")
    {:error, "Invalid comments data"}
  end
end
