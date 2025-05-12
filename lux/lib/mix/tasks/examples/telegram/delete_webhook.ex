defmodule Mix.Tasks.Telegram.DeleteWebhook do
  @moduledoc """
  Deletes a Telegram webhook.

  ## Usage

  ```
  mix telegram.delete_webhook YOUR_BOT_TOKEN
  ```
  """

  use Mix.Task
  alias Lux.Examples.DeleteTelegramWebhook

  @shortdoc "Deletes a Telegram webhook"

  @impl Mix.Task
  def run(args) do
    # Start all required applications
    [:hackney, :telemetry, :finch, :req, :jason, :lux]
    |> Enum.each(&Application.ensure_all_started/1)

    # Give a moment for everything to initialize
    :timer.sleep(500)

    case args do
      [token] ->
        # Run the webhook deletion script
        DeleteTelegramWebhook.run(token)

      _ ->
        # Print usage information
        IO.puts """
        Usage: mix telegram.delete_webhook YOUR_BOT_TOKEN

        Example:
          mix telegram.delete_webhook 123_456_789:ABCdefGHIjklMNOpqrSTUvwxYZ
        """
    end
  end
end
