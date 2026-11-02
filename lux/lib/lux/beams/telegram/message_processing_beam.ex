defmodule Lux.Beams.Telegram.MessageProcessingBeam do
  @moduledoc """
  A beam pipeline that coordinates Telegram message processing:
  1. Ingests raw Telegram message / update
  2. Analyzes content type (text, photo, audio, document, poll, etc.)
  3. Resolves thread context and forum supergroup topic
  4. Resolves reply hierarchy and quotes (API 7.0+)
  5. Parses bot commands and deep links
  6. Formats response messages into Telegram-compliant HTML or MarkdownV2
  """

  use Lux.Beam,
    name: "Telegram Message Processing Pipeline",
    description: "Orchestrates Telegram message ingestion, content classification, command parsing, and response formatting",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{
          type: :object,
          description: "Raw Telegram message payload"
        },
        bot_username: %{
          type: :string,
          description: "Optional bot username for command filtering"
        }
      },
      required: ["message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        analysis: %{type: :object},
        thread_context: %{type: :object},
        reply_context: %{type: :object},
        command_context: %{type: :object}
      },
      required: ["analysis", "thread_context", "reply_context"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Telegram.MessageProcessing.AnalyzeContent
  alias Lux.Prisms.Telegram.MessageProcessing.ManageThread
  alias Lux.Prisms.Telegram.MessageProcessing.ResolveReply
  alias Lux.Prisms.Telegram.MessageProcessing.ParseCommand

  sequence do
    # 1. Analyze message content
    step(:analysis, AnalyzeContent, %{
      message: [:input, :message]
    })

    # 2. Extract thread and forum topic context
    step(:thread_context, ManageThread, %{
      message: [:input, :message]
    })

    # 3. Resolve reply context and quote parameters
    step(:reply_context, ResolveReply, %{
      message: [:input, :message]
    })

    # 4. Parse potential command
    step(:command_context, ParseCommand, %{
      text: [:steps, :analysis, :result, :text],
      bot_username: [:input, :bot_username]
    })
  end

  @doc """
  Direct execution helper for processing a message map.
  """
  def process_message(message, opts \\ []) do
    bot_username = Keyword.get(opts, :bot_username)

    with {:ok, analysis} <- AnalyzeContent.handler(%{message: message}, %{}),
         {:ok, thread_ctx} <- ManageThread.handler(%{message: message}, %{}),
         {:ok, reply_ctx} <- ResolveReply.handler(%{message: message}, %{}),
         {:ok, cmd_ctx} <-
           ParseCommand.handler(%{text: analysis.text, bot_username: bot_username}, %{}) do
      {:ok,
       %{
         analysis: analysis,
         thread_context: thread_ctx,
         reply_context: reply_ctx,
         command_context: cmd_ctx
       }}
    end
  end
end
