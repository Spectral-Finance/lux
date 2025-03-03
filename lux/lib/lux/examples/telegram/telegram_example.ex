defmodule Lux.Examples.TelegramExample do
  @moduledoc """
  A simple example demonstrating how to use the TelegramBotLens module
  to interact with the Telegram Bot API.

  This example sends a text message, a panda picture, and a sticker
  to a specified chat ID.
  """

  alias Lux.Lenses.Telegram.Client

  @doc """
  Runs the example by sending a message, a panda picture, and a sticker
  to the specified chat ID.

  ## Parameters

  - `chat_id`: The chat ID to send the messages to
  - `token`: Your Telegram Bot API token

  ## Example

  ```elixir
  # Run the example with your chat ID and token
  Lux.Examples.TelegramExample.run("YOUR_CHAT_ID", "YOUR_BOT_TOKEN")
  ```
  """
  def run(chat_id, token) do
    IO.puts("Running Telegram Bot example...")

    # Send a text message
    send_message(chat_id, token)

    # Send a panda picture
    send_panda_picture(chat_id, token)

    # Send a sticker
    send_sticker(chat_id, token)

    IO.puts("Example completed successfully!")
  end

  defp send_message(chat_id, token) do
    message = "Hello from Lux TelegramBotLens example! 👋 Sent at #{DateTime.utc_now()}"

    IO.puts("Sending text message...")

    params = %{
      method: "sendMessage",
      chat_id: chat_id,
      text: message,
      token: token
    }

    url = "https://api.telegram.org/bot#{token}/sendMessage"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: Map.drop(params, [:url, :method, :token])
    }

    result = Client.make_request(lens, lens.params)

    case result do
      {:ok, response} ->
        IO.puts("✅ Message sent successfully!")
        IO.puts("Message ID: #{response["message_id"]}")

      {:error, error} ->
        IO.puts("❌ Failed to send message: #{inspect(error)}")
    end
  end

  defp send_panda_picture(chat_id, token) do
    # Use the same panda picture URL from the integration tests
    photo_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Grosser_Panda.JPG/330px-Grosser_Panda.JPG"
    caption = "Here's a cute panda! 🐼 Sent at #{DateTime.utc_now()}"

    IO.puts("Sending panda picture...")

    params = %{
      method: "sendPhoto",
      chat_id: chat_id,
      photo: photo_url,
      caption: caption,
      token: token
    }

    url = "https://api.telegram.org/bot#{token}/sendPhoto"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: Map.drop(params, [:url, :method, :token])
    }

    result = Client.make_request(lens, lens.params)

    case result do
      {:ok, response} ->
        IO.puts("✅ Panda picture sent successfully!")
        IO.puts("Message ID: #{response["message_id"]}")

      {:error, error} ->
        IO.puts("❌ Failed to send panda picture: #{inspect(error)}")
    end
  end

  defp send_sticker(chat_id, token) do
    # Use a sticker ID from the Telegram sticker set
    # Note: This sticker ID might expire over time
    sticker_id = "CAACAgUAAxkBAAEyOo9nwmKWV2cbpTTvvYb-3i3_COPWowACUAQAAi_32VWCTBgLkVLp0zYE"

    IO.puts("Sending sticker...")

    params = %{
      method: "sendSticker",
      chat_id: chat_id,
      sticker: sticker_id,
      token: token
    }

    url = "https://api.telegram.org/bot#{token}/sendSticker"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: Map.drop(params, [:url, :method, :token])
    }

    result = Client.make_request(lens, lens.params)

    case result do
      {:ok, response} ->
        IO.puts("✅ Sticker sent successfully!")
        IO.puts("Message ID: #{response["message_id"]}")

      {:error, error} ->
        IO.puts("❌ Failed to send sticker: #{inspect(error)}")

        # Try with an alternative sticker if the first one fails
        alternative_sticker_id = "CAACAgIAAxkBAAEKqPJlWU_AAWm-AAHlOzBF7AABYzJ-AAHXpgACGxsAAVGRAAHoC8HlhLEwBA"
        IO.puts("Trying with an alternative sticker...")

        alt_params = %{
          method: "sendSticker",
          chat_id: chat_id,
          sticker: alternative_sticker_id,
          token: token
        }

        alt_lens = %{
          url: url,
          method: :post,
          headers: [{"content-type", "application/json"}],
          params: Map.drop(alt_params, [:url, :method, :token])
        }

        alt_result = Client.make_request(alt_lens, alt_lens.params)

        case alt_result do
          {:ok, response} ->
            IO.puts("✅ Alternative sticker sent successfully!")
            IO.puts("Message ID: #{response["message_id"]}")

          {:error, error} ->
            IO.puts("❌ Failed to send alternative sticker: #{inspect(error)}")
        end
    end
  end
end
