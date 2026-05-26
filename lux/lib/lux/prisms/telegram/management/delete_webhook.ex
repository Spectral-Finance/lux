defmodule Lux.Prisms.Telegram.Management.DeleteWebhook do
  @moduledoc """
  A prism for removing webhook integration.
  """

  alias Lux.Integrations.Telegram.Client

  use Lux.Prism,
    name: "Delete Telegram Webhook",
    description: "Removes webhook integration if you decide to switch back to getUpdates",
    input_schema: %{
      type: :object,
      properties: %{
        drop_pending_updates: %{type: :boolean, description: "Pass True to drop all pending updates"}
      }
    }

  def handler(params, _agent) do
    case Client.request(:post, "/deleteWebhook", %{json: params}) do
      {:ok, %{"ok" => true, "result" => true}} ->
        {:ok, %{success: true}}

      {:ok, response} ->
        {:error, response}

      {:error, error} ->
        {:error, error}
    end
  end
end
