defmodule Lux.Prisms.Discord.Webhook.CreateWebhook do
  @moduledoc """
  Create a webhook for a Discord channel.

  This prism enables bots to create webhooks in text channels,
  allowing external services to send messages via Discord.

  Requires the \"Manage Webhooks\" permission in the target channel.

  ## Examples

      iex> CreateWebhook.handler(%{
      ...>   channel_id: \"123456789\",
      ...>   name: \"Alert Bot\",
      ...>   avatar_url: \"https://example.com/avatar.png\"
      ...> }, %{name: \"Agent\"})
      {:ok, %{
        webhook_id: \"987654321\",
        name: \"Alert Bot\",
        channel_id: \"123456789\"
      }}
  """

  use Lux.Prism,
    name: "Create Discord Webhook",
    description: "Creates a webhook in a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to create the webhook in",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "The name of the webhook (1-80 characters)",
          minLength: 1,
          maxLength: 80
        },
        avatar_url: %{
          type: :string,
          description: "Optional URL for the webhook's avatar (PNG/JPEG/WebP)"
        }
      },
      required: ["channel_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        webhook_id: %{
          type: :string,
          description: "The ID of the created webhook"
        },
        name: %{
          type: :string,
          description: "The name of the webhook"
        },
        channel_id: %{
          type: :string,
          description: "The channel where the webhook was created"
        },
        url: %{
          type: :string,
          description: "The full webhook URL for posting messages"
        },
        avatar_url: %{
          type: :string,
          description: "The avatar URL if provided"
        }
      },
      required: ["webhook_id", "name", "channel_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Creates a webhook in the specified Discord channel.

  Returns {:ok, result_map} on success, {:error, {status, message}} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, any()}
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_channel_id(params),
         {:ok, name} <- validate_name(params),
         avatar_url <- Map.get(params, :avatar_url) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating webhook '#{name}' in channel #{channel_id}")

      body = %{"name" => name}
      body = if(avatar_url, Map.put(body, "avatar", avatar_url), body)

      case Client.request(:post, "/channels/#{channel_id}/webhooks", %{json: body}) do
        {:ok,
         %{
           "id" => webhook_id,
           "name" => webhook_name,
           "channel_id" => returned_channel,
           "url" => url
         } = resp} ->
          Logger.info("Successfully created webhook #{webhook_id} in channel #{returned_channel}")

          {:ok,
           %{
             webhook_id: webhook_id,
             name: webhook_name,
             channel_id: returned_channel,
             url: url,
             avatar_url: resp["avatar"]
           }}

        {:ok, %{"message" => message}} when is_binary(message) ->
          # Discord returns 4xx/5xx errors with message field
          {:error, {400, message}}

        {:error, {status, message}} ->
          Logger.error(
            "Failed to create webhook in channel #{channel_id}: #{inspect({status, message})}"
          )

          {:error, {status, message}}

        {:error, error} ->
          Logger.error("Failed to create webhook in channel #{channel_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_channel_id(params) do
    case Map.fetch(params, :channel_id) do
      {:ok, val} when is_binary(val) and byte_size(val) > 0 -> {:ok, val}
      _ -> {:error, "Missing or invalid channel_id"}
    end
  end

  defp validate_name(params) do
    case Map.fetch(params, :name) do
      {:ok, val} when is_binary(val) and byte_size(val) >= 1 and byte_size(val) <= 80 ->
        {:ok, val}

      _ ->
        {:error, "Missing or invalid name (must be 1-80 characters)"}
    end
  end
end
