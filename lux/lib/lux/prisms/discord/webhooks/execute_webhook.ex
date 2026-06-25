defmodule Lux.Prisms.Discord.Webhooks.ExecuteWebhook do
  @moduledoc """
  A prism for sending messages through Discord webhooks.
  """

  use Lux.Prism,
    name: "Execute Discord Webhook",
    description: "Sends a message through a Discord webhook",
    input_schema: %{
      type: :object,
      properties: %{
        webhook_id: %{type: :string, description: "The webhook ID", pattern: "^[0-9]{17,20}$"},
        webhook_token: %{type: :string, description: "The webhook token"},
        content: %{type: :string, description: "Message content", maxLength: 2000},
        username: %{type: :string, description: "Optional webhook username override"},
        avatar_url: %{type: :string, description: "Optional webhook avatar URL"},
        wait: %{type: :boolean, description: "Whether Discord should return the created message"}
      },
      required: ["webhook_id", "webhook_token", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{type: :boolean, description: "Whether the webhook message was sent"},
        message_id: %{type: :string, description: "The created message ID"},
        webhook_id: %{type: :string, description: "The webhook ID"}
      },
      required: ["sent"]
    }

  alias Lux.Integrations.Discord.Webhooks

  @impl Lux.Prism
  def handler(params, _agent) do
    with {:ok, webhook_id} <- validate_binary(params, :webhook_id),
         {:ok, webhook_token} <- validate_binary(params, :webhook_token),
         {:ok, content} <- validate_binary(params, :content) do
      payload =
        %{content: content}
        |> maybe_put(:username, Map.get(params, :username))
        |> maybe_put(:avatar_url, Map.get(params, :avatar_url))

      opts =
        params
        |> request_opts()
        |> Map.put(:wait, Map.get(params, :wait, true))

      case Webhooks.execute(webhook_id, webhook_token, payload, opts) do
        {:ok, %{"id" => message_id}} ->
          {:ok, %{sent: true, message_id: message_id, webhook_id: webhook_id}}

        {:ok, _body} ->
          {:ok, %{sent: true, webhook_id: webhook_id}}

        {:error, error} ->
          {:error, normalize_error(error)}
      end
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

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
