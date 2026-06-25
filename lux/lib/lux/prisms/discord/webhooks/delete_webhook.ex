defmodule Lux.Prisms.Discord.Webhooks.DeleteWebhook do
  @moduledoc """
  A prism for deleting Discord webhooks.
  """

  use Lux.Prism,
    name: "Delete Discord Webhook",
    description: "Deletes a Discord webhook",
    input_schema: %{
      type: :object,
      properties: %{
        webhook_id: %{type: :string, description: "The webhook ID", pattern: "^[0-9]{17,20}$"}
      },
      required: ["webhook_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean, description: "Whether the webhook was deleted"},
        webhook_id: %{type: :string, description: "The deleted webhook ID"}
      },
      required: ["deleted"]
    }

  alias Lux.Integrations.Discord.Webhooks

  @impl Lux.Prism
  def handler(params, _agent) do
    with {:ok, webhook_id} <- validate_binary(params, :webhook_id) do
      case Webhooks.delete(webhook_id, request_opts(params)) do
        {:ok, _body} -> {:ok, %{deleted: true, webhook_id: webhook_id}}
        {:error, error} -> {:error, normalize_error(error)}
      end
    end
  end

  defp request_opts(params),
    do: Map.take(params, [:plug, :token, :token_type, :retries, :retry_delay_ms])

  defp validate_binary(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp normalize_error({status, %{"message" => message}}), do: {status, message}
  defp normalize_error(error), do: error
end
