# examples/telegram_bot.exs
#
# Run with:
#   TELEGRAM_BOT_TOKEN="your_token" mix run examples/telegram_bot.exs

defmodule ExampleTelegramAgent do
  @moduledoc """
  Example Lux Agent that receives TelegramUpdate signals and responds with echo and status messages.
  """
  use Lux.Agent,
    name: "Telegram Echo Bot",
    description: "Echoes user messages and handles basic Telegram bot commands",
    goal: "Provide responsive communication over Telegram"

  alias Lux.Signals.TelegramUpdate
  alias Lux.Telegram.Messaging
  alias Lux.Telegram.Keyboards

  require Logger

  @doc """
  Handles incoming Telegram update signals.
  """
  def handle_signal(%Lux.Signal{schema_id: Lux.Schemas.TelegramUpdateSchema} = signal) do
    chat_id = TelegramUpdate.chat_id(signal)
    text = TelegramUpdate.text(signal)
    update_id = TelegramUpdate.update_id(signal)

    Logger.info("Received Telegram update #{update_id} from chat #{chat_id}: #{inspect(text)}")

    if chat_id && text do
      process_message(chat_id, text)
    else
      :ok
    end
  end

  def handle_signal(_other_signal), do: :ok

  defp process_message(chat_id, "/start") do
    welcome_text = "👋 Welcome to the Lux Telegram Bot Example!\nSend any message to echo it back."
    keyboard = Keyboards.inline_keyboard([
      [Keyboards.inline_button("Lux Documentation", url: "https://lux.spectrallabs.xyz")]
    ])

    Messaging.send_message(chat_id, welcome_text, %{reply_markup: keyboard})
  end

  defp process_message(chat_id, "/ping") do
    Messaging.send_message(chat_id, "🏓 Pong! Lux Agent is running smoothly.")
  end

  defp process_message(chat_id, text) do
    Messaging.send_message(chat_id, "🤖 Echo from Lux Agent:\n\n#{text}")
  end
end

defmodule TelegramBotRunner do
  @moduledoc """
  Configures and starts the Telegram Poller or Webhook.
  """
  alias Lux.Telegram.Poller
  require Logger

  def run do
    token = System.get_env("TELEGRAM_BOT_TOKEN") || "test_token"

    Logger.info("Starting Telegram Bot Runner...")

    handler = fn signal ->
      ExampleTelegramAgent.handle_signal(signal)
    end

    {:ok, poller_pid} = Poller.start_link(%{
      token: token,
      handler: handler,
      poll_interval: 1000,
      timeout: 30,
      autostart: true
    })

    Logger.info("Poller started: #{inspect(poller_pid)}. Listening for updates...")

    # Keep process alive if running interactively
    unless IEx.started?() do
      Process.sleep(:infinity)
    end
  end
end

TelegramBotRunner.run()
