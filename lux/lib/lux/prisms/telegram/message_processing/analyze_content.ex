defmodule Lux.Prisms.Telegram.MessageProcessing.AnalyzeContent do
  @moduledoc """
  A prism for analyzing Telegram message content across all message types.
  Identifies text, media, service events, extracts entities, and computes content metrics.
  """

  use Lux.Prism,
    name: "Analyze Telegram Message Content",
    description: "Analyzes Telegram message payload, detects message types, extracts media and entity details",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{
          type: :object,
          description: "Raw Telegram message payload"
        }
      },
      required: ["message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        message_id: %{type: :integer},
        message_type: %{type: :string},
        text: %{type: :string},
        sender: %{type: :object},
        chat: %{type: :object},
        text_stats: %{type: :object},
        media_info: %{type: :object},
        entities: %{type: :array},
        flags: %{type: :object}
      },
      required: ["message_type", "flags"]
    }

  alias Lux.Integrations.Telegram.MessageProcessing.ContentAnalyzer
  require Logger

  def handler(%{message: message}, _agent) when is_map(message) do
    case ContentAnalyzer.analyze(message) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(%{"message" => message}, agent) when is_map(message) do
    handler(%{message: message}, agent)
  end

  def handler(message, agent) when is_map(message) and not is_map_key(message, :message) do
    handler(%{message: message}, agent)
  end

  def handler(_, _), do: {:error, "Invalid input: expected message object"}
end
