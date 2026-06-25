defmodule Lux.Prisms.Discord.Webhooks.CreateWebhook do
  @moduledoc """
  A prism for creating Discord webhooks.
  """

  use Lux.Prism,
    name: "Create Discord Webhook",
    description: "Creates a webhook in a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "The channel ID", pattern: "^[0-9]{17,20}$"},
        name: %{type: :string, description: "Webhook name", minLength: 1, maxLength: 80},
        avatar: %{type: :string, description: "Optional base64 avatar data"}
      },
      required: ["channel_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{type: :boolean, description: "Whether the webhook was created"},
        webhook_id: %{type: :string, description: "The created webhook ID"},
        channel_id: %{type: :string, description: "The webhook channel ID"},
        name: %{type: :string, description: "The webhook name"},
        token: %{type: :string, description: "The webhook token returned by Discord"}
      },
      required: ["created"]
    }

  alias Lux.Integrations.Discord.Webhooks

  require Logger

  @impl Lux.Prism
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_binary(params, :channel_id),
         {:ok, name} <- validate_binary(params, :name) do
      attrs =
        %{name: name}
        |> maybe_put(:avatar, Map.get(params, :avatar))

      Logger.info(
        "#{agent_name(agent)} creating Discord webhook #{name} in channel #{channel_id}"
      )

      case Webhooks.create(channel_id, attrs, request_opts(params)) do
        {:ok, %{"id" => webhook_id} = webhook} ->
          {:ok,
           %{
             created: true,
             webhook_id: webhook_id,
             channel_id: webhook["channel_id"] || channel_id,
             name: webhook["name"] || name,
             token: webhook["token"]
           }}

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

  defp agent_name(%{agent: %{name: name}}), do: name
  defp agent_name(%{name: name}), do: name
  defp agent_name(_agent), do: "Unknown Agent"
end
