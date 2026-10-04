defmodule Lux.Beams.Telegram.MessageProcessingBeam do
  @moduledoc """
  End-to-end Lux Beam for ingesting, analyzing, routing, and formatting Telegram messages and commands.
  """

  use Lux.Beam,
    name: "Telegram Message Processing Beam",
    description: "Orchestrates Telegram message ingestion, content analysis, command routing, and formatted response dispatch.",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Raw message or command text"},
        chat_id: %{type: :integer, description: "Telegram chat identifier"},
        user_id: %{type: :integer, description: "Sender user identifier"},
        target_format: %{type: :string, default: "markdown_v2", description: "Target response parse mode"}
      },
      required: ["text", "chat_id"]
    }

  alias Lux.Prisms.Telegram.{
    CommandRouterPrism,
    FormatConversionPrism,
    MessageParserPrism
  }

  sequence do
    # Step 1: Parse and analyze message content
    step(:analysis, MessageParserPrism, %{
      text: [:input, :text]
    })

    # Step 2: Route if command, or format analysis
    branch {__MODULE__, :is_command?} do
      true ->
        step(:route_command, CommandRouterPrism, %{
          command_text: [:input, :text]
        })

      false ->
        step(:format_output, FormatConversionPrism, %{
          text: [:input, :text],
          source_format: "markdown",
          target_format: "markdown_v2"
        })
    end
  end

  @doc """
  Determines if input text represents a bot command.
  """
  def is_command?(ctx) do
    text =
      case ctx do
        %{input: %{text: t}} when is_binary(t) -> t
        %{input: %{"text" => t}} when is_binary(t) -> t
        _ -> ""
      end

    String.starts_with?(String.trim(text), "/")
  end
end
