defmodule Lux.Prisms.Telegram.Webhook.DeleteWebhook do
  @moduledoc """
  A prism for removing a webhook integration via the Telegram Bot API.

  This prism provides an interface to call the deleteWebhook endpoint, which
  removes the webhook integration if set. To remove the webhook after using
  the setWebhook method, use this with no parameters or set the url to an empty string.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /deleteWebhook
  - Optional drop_pending_updates parameter
  - Returns true on success

  ## Examples

      iex> DeleteWebhook.handler(%{}, %{name: "Agent"})
      {:ok, %{success: true}}
  """

  use Lux.Prism,
    name: "Delete Telegram Webhook",
    description: "Removes the webhook integration via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass True to drop all pending updates"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the webhook was successfully deleted"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to delete the webhook.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} deleting webhook")

    request_body = Map.take(params, [:drop_pending_updates])
    request_opts = %{json: request_body}
    request_opts = maybe_add_plug(request_opts, params[:plug])

    case Client.request(:post, "/deleteWebhook", request_opts) do
      {:ok, %{"result" => true}} ->
        Logger.info("Successfully deleted webhook")
        {:ok, %{success: true}}

      {:error, {status, %{"description" => description}}} ->
        {:error, "Failed to delete webhook: #{description} (HTTP #{status})"}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to delete webhook: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to delete webhook: #{inspect(error)}"}
    end
  end

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Map.put(opts, :plug, plug)
end
