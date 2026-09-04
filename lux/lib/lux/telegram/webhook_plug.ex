defmodule Lux.Telegram.WebhookPlug do
  @moduledoc """
  Plug endpoint for receiving and processing Telegram Bot API webhook updates.
  Delegates all operations to `Lux.Telegram.Webhook`.
  """

  @behaviour Plug

  @doc """
  Sets up webhook URL and options via `Lux.Telegram.Webhook`.
  """
  defdelegate set_webhook(client_or_url, url_or_opts \\ [], opts \\ []), to: Lux.Telegram.Webhook

  @doc """
  Deletes the current webhook via `Lux.Telegram.Webhook`.
  """
  defdelegate delete_webhook(client_or_opts \\ [], opts \\ []), to: Lux.Telegram.Webhook

  @doc """
  Retrieves current webhook information via `Lux.Telegram.Webhook`.
  """
  defdelegate get_webhook_info(client_or_opts \\ []), to: Lux.Telegram.Webhook

  @impl true
  defdelegate init(opts), to: Lux.Telegram.Webhook

  @impl true
  defdelegate call(conn, opts), to: Lux.Telegram.Webhook
end
