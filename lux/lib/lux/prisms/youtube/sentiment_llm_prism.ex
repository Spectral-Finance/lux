defmodule Lux.Prisms.YouTube.SentimentLLMPrism do
  use Lux.Prism,
    name: "Sentiment LLM",
    description: "Uses LLM to evaluate sentiment",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string}
      },
      required: ["text"]
    }

  def handler(%{text: text}, _ctx) do
    prompt = "Analyze the sentiment of this YouTube comment. Reply with exactly one of these words: positive, negative, spam, neutral. Comment: \"#{text}\""
    case Lux.LLM.call(prompt, [], %{}) do
      {:ok, %Lux.LLM.Response{content: content}} ->
        sentiment =
          content
          |> String.downcase()
          |> String.trim()
          |> String.to_existing_atom()
        {:ok, %{sentiment: sentiment}}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
