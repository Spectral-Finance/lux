defmodule Lux.Beams.YouTube.SentimentAnalysisBeam do
  use Lux.Beam,
    name: "YouTube Sentiment Analysis",
    description: "Evaluates sentiment of YouTube comments",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string}
      },
      required: ["text"]
    }

  sequence do
    step(:sentiment, Lux.Prisms.YouTube.SentimentLLMPrism, %{text: :text})
  end
end
