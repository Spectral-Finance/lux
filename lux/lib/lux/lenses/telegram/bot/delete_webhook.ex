defmodule Lux.Lenses.Telegram.Bot.DeleteWebhook do
  @moduledoc """
  A lens for removing a webhook via the Telegram Bot API.

  This lens removes a previously set webhook integration, allowing you to
  switch back to long polling via getUpdates.

  ## Examples

      iex> DeleteWebhook.focus(%{})
      {:ok, %{deleted: true, description: "Webhook was deleted"}}

      iex> DeleteWebhook.focus(%{drop_pending_updates: true})
      {:ok, %{deleted: true, description: "Webhook was deleted"}}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Delete Telegram Webhook",
    description: "Removes the webhook integration and switches back to getUpdates",
    url: Telegram.api_url("deleteWebhook"),
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass True to drop all pending updates"
        }
      },
      required: []
    }

  @doc """
  Transforms the Telegram API response into a clean format.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => true, "description" => description}) do
    {:ok, %{deleted: true, description: description}}
  end

  def after_focus(%{"ok" => true, "result" => true}) do
    {:ok, %{deleted: true, description: "Webhook was deleted"}}
  end

  def after_focus(%{"ok" => false, "error_code" => 429, "parameters" => %{"retry_after" => retry_after}} = error) do
    {:error, %{
      reason: :rate_limited,
      retry_after: retry_after,
      description: error["description"]
    }}
  end

  def after_focus(%{"ok" => false, "description" => description, "error_code" => code}) do
    {:error, %{reason: :api_error, error_code: code, description: description}}
  end

  def after_focus(%{"description" => description}) do
    {:error, %{reason: :api_error, description: description}}
  end
end
