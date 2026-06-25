defmodule Lux.Prisms.Discord.Webhooks.UpdateWebhook do
  @moduledoc """
  A prism for updating Discord webhooks.
  """

  use Lux.Prism,
    name: "Update Discord Webhook",
    description: "Updates a Discord webhook",
    input_schema: %{
      type: :object,
      properties: %{
        webhook_id: %{type: :string, description: "The webhook ID", pattern: "^[0-9]{17,20}$"},
        name: %{type: :string, description: "Webhook name", minLength: 1, maxLength: 80},
        avatar: %{type: :string, description: "Optional base64 avatar data"},
        channel_id: %{type: :string, description: "Optional destination channel ID"}
      },
      required: ["webhook_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{type: :boolean, description: "Whether the webhook was updated"},
        webhook_id: %{type: :string, description: "The updated webhook ID"},
        channel_id: %{type: :string, description: "The webhook channel ID"},
        name: %{type: :string, description: "The webhook name"}
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Webhooks

  @impl Lux.Prism
  def handler(params, _agent) do
    with {:ok, webhook_id} <- validate_binary(params, :webhook_id),
         {:ok, attrs} <- webhook_attrs(params) do
      case Webhooks.update(webhook_id, attrs, request_opts(params)) do
        {:ok, webhook} ->
          {:ok,
           %{
             updated: true,
             webhook_id: webhook["id"] || webhook_id,
             channel_id: webhook["channel_id"],
             name: webhook["name"]
           }}

        {:error, error} ->
          {:error, normalize_error(error)}
      end
    end
  end

  defp webhook_attrs(params) do
    attrs =
      %{}
      |> maybe_put(:name, Map.get(params, :name))
      |> maybe_put(:avatar, Map.get(params, :avatar))
      |> maybe_put(:channel_id, Map.get(params, :channel_id))

    if attrs == %{}, do: {:error, "At least one webhook field is required"}, else: {:ok, attrs}
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
