defmodule Lux.Examples.DeleteTelegramWebhook do
  @moduledoc """
  A simple script to delete a Telegram webhook.

  This is useful when a webhook is stuck or when you want to switch from webhook mode
  to polling mode.
  """

  alias Lux.Lenses.Telegram.Client

  @doc """
  Deletes the webhook for the specified Telegram bot token.

  ## Parameters

  - `token`: Your Telegram Bot API token

  ## Example

  ```elixir
  # Delete the webhook for your bot
  Lux.Examples.DeleteTelegramWebhook.delete_webhook("YOUR_BOT_TOKEN")
  ```
  """
  def delete_webhook(token) do
    IO.puts("🔄 Deleting webhook for bot...")

    # First check the current webhook status
    case get_webhook_info(token) do
      {:ok, info} ->
        if info["url"] == "" or info["url"] == nil do
          IO.puts("✅ No webhook is currently set. Nothing to delete.")
          :ok
        else
          IO.puts("ℹ️ Current webhook is set to: #{info["url"]}")
          perform_webhook_deletion(token)
        end

      {:error, error} ->
        IO.puts("❌ Error checking webhook status: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Main entry point for the script.

  ## Parameters

  - `token`: Your Telegram Bot API token

  ## Example

  ```elixir
  # Run the script with your token
  Lux.Examples.DeleteTelegramWebhook.run("YOUR_BOT_TOKEN")
  ```
  """
  def run(token) do
    IO.puts("🤖 Telegram Webhook Deletion Tool")
    IO.puts("================================")

    result = delete_webhook(token)

    case result do
      :ok ->
        IO.puts("\n✅ Operation completed successfully.")

        # Verify the webhook is gone
        case get_webhook_info(token) do
          {:ok, info} ->
            if info["url"] == "" or info["url"] == nil do
              IO.puts("✅ Verified: No webhook is set.")
            else
              IO.puts("⚠️ WARNING: Webhook still appears to be set to: #{info["url"]}")
            end

          {:error, error} ->
            IO.puts("❌ Error verifying webhook status: #{inspect(error)}")
        end

      {:error, error} ->
        IO.puts("\n❌ Operation failed: #{inspect(error)}")
    end

    IO.puts("\n🔄 You can now use polling mode with your bot.")
  end

  # Perform the actual webhook deletion with retries
  defp perform_webhook_deletion(token) do
    # First attempt - standard deletion
    IO.puts("🔄 Attempting standard webhook deletion...")

    url = "https://api.telegram.org/bot#{token}/deleteWebhook"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: %{}  # Empty map for standard deletion
    }

    case Client.make_request(lens, lens.params) do
      {:ok, true} ->
        IO.puts("✅ Webhook deleted successfully!")
        verify_webhook_deleted(token)

      {:ok, response} ->
        IO.puts("❌ Standard deletion failed with response: #{inspect(response)}")
        # Try forceful deletion
        forceful_webhook_deletion(token)

      {:error, error} ->
        IO.puts("❌ Standard deletion failed: #{inspect(error)}")
        # Try forceful deletion
        forceful_webhook_deletion(token)
    end
  end

  # Try a more forceful deletion with drop_pending_updates
  defp forceful_webhook_deletion(token) do
    IO.puts("🔄 Attempting forceful webhook deletion with drop_pending_updates...")

    url = "https://api.telegram.org/bot#{token}/deleteWebhook"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: %{drop_pending_updates: true}
    }

    case Client.make_request(lens, lens.params) do
      {:ok, true} ->
        IO.puts("✅ Webhook forcefully deleted!")
        verify_webhook_deleted(token)

      {:ok, response} ->
        IO.puts("❌ Forceful deletion failed with response: #{inspect(response)}")
        {:error, response}

      {:error, error} ->
        IO.puts("❌ Forceful deletion failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # Verify that the webhook was actually deleted
  defp verify_webhook_deleted(token) do
    IO.puts("🔍 Verifying webhook deletion...")

    case get_webhook_info(token) do
      {:ok, info} ->
        if info["url"] == "" or info["url"] == nil do
          IO.puts("✅ Webhook deletion verified - webhook URL is empty")
          :ok
        else
          IO.puts("⚠️ Webhook still appears to be set to: #{info["url"]}")
          IO.puts("🔄 Attempting one final forceful deletion...")

          # One final attempt with maximum force
          url = "https://api.telegram.org/bot#{token}/deleteWebhook"

          lens = %{
            url: url,
            method: :post,
            headers: [{"content-type", "application/json"}],
            params: %{drop_pending_updates: true}
          }

          case Client.make_request(lens, lens.params) do
            {:ok, true} ->
              IO.puts("✅ Final forceful deletion attempt completed")

              # Double-check one more time
              case get_webhook_info(token) do
                {:ok, final_info} ->
                  if final_info["url"] == "" or final_info["url"] == nil do
                    IO.puts("✅ Final verification successful - webhook is gone")
                    :ok
                  else
                    IO.puts("⚠️ CRITICAL: Webhook still set after multiple deletion attempts")
                    IO.puts("⚠️ You may need to contact Telegram support or wait and try again later")
                    {:error, :webhook_persists}
                  end

                {:error, error} ->
                  IO.puts("❌ Error during final verification: #{inspect(error)}")
                  {:error, error}
              end

            {:ok, response} ->
              IO.puts("❌ Final deletion attempt failed with response: #{inspect(response)}")
              {:error, response}

            {:error, error} ->
              IO.puts("❌ Final deletion attempt failed: #{inspect(error)}")
              {:error, error}
          end
        end

      {:error, error} ->
        IO.puts("❌ Error verifying webhook deletion: #{inspect(error)}")
        {:error, error}
    end
  end

  # Get webhook info
  defp get_webhook_info(token) do
    url = "https://api.telegram.org/bot#{token}/getWebhookInfo"

    lens = %{
      url: url,
      method: :post,
      headers: [{"content-type", "application/json"}],
      params: %{}  # Empty map since getWebhookInfo doesn't need parameters
    }

    case Client.make_request(lens, lens.params) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, error}
    end
  end
end
