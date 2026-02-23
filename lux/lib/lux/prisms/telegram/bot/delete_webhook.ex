defmodule Lux.Prisms.Telegram.Bot.DeleteWebhook do
  @moduledoc """
  A prism for removing the webhook configuration from the Telegram bot.

  After deleting the webhook, the bot can receive updates via getUpdates (long polling).
  You can optionally drop all pending updates during deletion.

  ## Examples

      iex> DeleteWebhook.handler(%{}, %{name: "Agent"})
      {:ok, %{success: true, description: "Webhook was deleted"}}

      iex> DeleteWebhook.handler(%{drop_pending_updates: true}, %{name: "Agent"})
      {:ok, %{success: true, description: "Webhook was deleted"}}
  """

  use Lux.Prism,
    name: "Delete Telegram Webhook",
    description: "Removes the webhook configuration from the Telegram bot, enabling polling",
    input_schema: %{
      type: :object,
      properties: %{
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass true to drop all pending updates when deleting the webhook"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the webhook was successfully deleted"
        },
        description: %{
          type: :string,
          description: "Human-readable description of the result"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} deleting Telegram webhook")

    body =
      params
      |> Map.take([:drop_pending_updates])
      |> then(fn m -> if map_size(m) == 0, do: %{}, else: m end)

    request_opts = %{json: body}
    request_opts = if plug = params[:plug], do: Map.put(request_opts, :plug, plug), else: request_opts

    case Client.request(:post, "/deleteWebhook", request_opts) do
      {:ok, %{"ok" => true, "result" => true, "description" => desc}} ->
        Logger.info("Webhook deleted: #{desc}")
        {:ok, %{success: true, description: desc}}

      {:ok, %{"ok" => true, "result" => true}} ->
        {:ok, %{success: true, description: "Webhook was deleted"}}

      {:ok, %{"ok" => false, "description" => description}} ->
        {:error, "Failed to delete webhook: #{description}"}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to delete webhook: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to delete webhook: #{inspect(error)}"}
    end
  end
end
