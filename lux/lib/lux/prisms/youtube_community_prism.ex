defmodule Lux.Prisms.YouTubeCommunityPrism do
  @moduledoc """
  A Prism for autonomous agents to manage YouTube community interactions,
  moderate comments, analyze viewer sentiment, and generate context-aware replies.

  ## Examples

      iex> Lux.Prisms.YouTubeCommunityPrism.run(%{
      ...>   action: "sentiment",
      ...>   payload: %{text: "This tutorial was incredible, thank you!"}
      ...> })
      {:ok, %{action: "sentiment", result: %{score: 1.0, classification: :positive, intent: :praise}}}
  """

  use Lux.Prism,
    name: "YouTube Community Prism",
    description: "Moderates YouTube comments, extracts viewer sentiment, schedules community posts, and drafts creator replies",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["moderate", "sentiment", "reply", "process", "schedule_post", "batch_sentiment"],
          description: "Operation to execute on community data",
          default: "process"
        },
        payload: %{
          type: :object,
          description: "Payload data including comment text, author name, or post content"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: :object}
      },
      required: ["action", "result"]
    }

  alias Lux.Community.YouTube

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action", "process")
    payload = Map.get(input, :payload) || Map.get(input, "payload", %{})

    case execute_action(action, payload) do
      {:ok, result} ->
        {:ok, %{action: action, result: result}}

      {:error, reason} ->
        {:error, "YouTubeCommunityPrism error on action '#{action}': #{inspect(reason)}"}
    end
  end

  defp execute_action("moderate", payload) do
    text = Map.get(payload, :text) || Map.get(payload, "text", "")
    {:ok, YouTube.moderate_comment(text)}
  end

  defp execute_action("sentiment", payload) do
    text = Map.get(payload, :text) || Map.get(payload, "text", "")
    {:ok, YouTube.analyze_sentiment(text)}
  end

  defp execute_action("reply", payload) do
    text = Map.get(payload, :text) || Map.get(payload, "text", "")
    author = Map.get(payload, :author) || Map.get(payload, "author", "Viewer")
    persona = Map.get(payload, :persona) || Map.get(payload, "persona", "Creator")
    {:ok, YouTube.generate_reply(text, author, persona: persona)}
  end

  defp execute_action("process", payload) do
    {:ok, YouTube.process_comment(payload)}
  end

  defp execute_action("schedule_post", payload) do
    YouTube.schedule_post(payload)
  end

  defp execute_action("batch_sentiment", payload) do
    comments = Map.get(payload, :comments) || Map.get(payload, "comments", [])
    {:ok, YouTube.analyze_batch_sentiment(comments)}
  end

  defp execute_action(unknown, _payload) do
    {:error, "Unknown action: #{unknown}"}
  end
end
