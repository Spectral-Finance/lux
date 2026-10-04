defmodule Lux.Agents.TelegramAgent do
  @moduledoc """
  Autonomous Telegram AI Agent implementation for the Lux Framework.

  Provides conversational reasoning, automated command routing, thread history tracking,
  and financial signal processing for Telegram bots and DeFi communities.
  """

  use Lux.Agent,
    name: "Telegram Assistant Agent",
    description: "Autonomous AI agent that parses, analyzes, routes, and replies to Telegram messages, commands, and callback queries.",
    goal: "Provide responsive, secure, and intelligent message processing, DeFi command execution, and conversation management on Telegram.",
    prisms: [
      Lux.Prisms.Telegram.MessageParserPrism,
      Lux.Prisms.Telegram.CommandRouterPrism,
      Lux.Prisms.Telegram.FormatConversionPrism,
      Lux.Prisms.Telegram.ThreadManagerPrism,
      Lux.Prisms.Telegram.CallbackQueryPrism
    ],
    signal_handlers: [
      {Lux.Signals.Telegram.TelegramMessageSignal, :handle_message_signal},
      {Lux.Signals.Telegram.TelegramCommandSignal, :handle_command_signal},
      {Lux.Signals.Telegram.TelegramCallbackSignal, :handle_callback_signal}
    ],
    llm_config: %{
      messages: [
        %{
          role: "system",
          content: """
          You are a Telegram AI Assistant in the Lux Framework specialized in DeFi, Web3,
          and automated community assistance. Always provide clear, concise, and structured
          responses formatted with Telegram MarkdownV2 or HTML.
          """
        }
      ]
    }

  require Logger

  @doc """
  Processes an incoming Telegram message through the agent's LLM or command router.
  """
  def process_message(agent, message_payload) do
    Logger.info("TelegramAgent processing message: #{inspect(message_payload[:text] || message_payload["text"])}")

    with {:ok, analysis} <- Lux.Prisms.Telegram.MessageParserPrism.handler(%{text: message_payload[:text] || message_payload["text"] || ""}, agent) do
      {:ok, %{
        processed: true,
        analysis: analysis,
        chat_id: message_payload[:chat_id] || message_payload["chat_id"]
      }}
    end
  end

  @doc """
  Signal handler for incoming TelegramMessageSignal.
  """
  def handle_message_signal(%Lux.Signal{payload: payload} = _signal, _context) do
    Logger.info("TelegramAgent received TelegramMessageSignal for chat #{payload["chat_id"] || payload[:chat_id]}")
    {:ok, %{status: :handled, signal: :telegram_message}}
  end

  @doc """
  Signal handler for incoming TelegramCommandSignal.
  """
  def handle_command_signal(%Lux.Signal{payload: payload} = _signal, _context) do
    Logger.info("TelegramAgent received TelegramCommandSignal: /#{payload["command"] || payload[:command]}")
    {:ok, %{status: :handled, signal: :telegram_command}}
  end

  @doc """
  Signal handler for incoming TelegramCallbackSignal.
  """
  def handle_callback_signal(%Lux.Signal{payload: payload} = _signal, _context) do
    Logger.info("TelegramAgent received TelegramCallbackSignal: #{payload["action"] || payload[:action]}")
    {:ok, %{status: :handled, signal: :telegram_callback}}
  end
end
