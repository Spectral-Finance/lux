defmodule Lux.Prisms.Discord.Webhook.CreateWebhook do
  @moduledoc """
  A prism for creating a Discord webhook.

  Creates a webhook in a text channel with custom name, avatar, and reason.
  """

  use Lux.Prism,
    name: "Create Discord Webhook",
    description: "Creates a new webhook in a Discord channel",
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
          description: "Webhook name (1-80 characters)",
          minLength: 1,
          maxLength: 80
        },
        avatar: %{
          type: :string,
          description: "Base64 encoded avatar image (max 256KB)"
        },
        reason: %{
          type: :string,
          description: "Audit log reason"
        }
      },
      required: ["channel_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{
          type: :boolean,
          description: "Whether webhook was successfully created"
        },
        webhook_id: %{
          type: :string,
          description: "The created webhook ID"
        },
        token: %{
          type: :string,
          description: "Webhook token for authentication"
        },
        url: %{
          type: :string,
          description: "Full webhook URL"
        },
        name: %{
          type: :string,
          description: "Webhook name"
        },
        channel_id: %{
          type: :string,
          description: "Channel ID where webhook was created"
        }
      },
      required: ["created"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @doc """
  Creates a new webhook in a channel.

  Returns {:ok, %{created: true, webhook_id: id, token: token, url: url, ...}} on success.
  Returns {:error, {status, message}} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, any()}
  def handler(params, agent) do
    with {:ok, channel_id} <- Helpers.validate_string(params, "channel_id"),
         {:ok, name} <- Helpers.validate_string(params, "name"),
         {:ok, avatar} <- Helpers.validate_string(params, "avatar", nil),
         {:ok, reason} <- Helpers.validate_string(params, "reason", nil) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating webhook '#{name}' in channel #{channel_id}")

      body = %{"name" => name}
      |> Map.put(:avatar, avatar)
      |> Enum.filter(fn {_, v} -> v != nil end)
      |> Enum.into(%{})

      opts = if reason, do: [headers: [{"X-Audit-Log-Reason", URI.encode_www_form(reason)}]], else: []

      case Client.request(:post, "/channels/#{channel_id}/webhooks", Keyword.merge([json: body], opts)) do
        {:ok, %{"id" => webhook_id, "token" => token, "name" => name, "channel_id" => channel_id}} ->
          url = "https://discord.com/api/webhooks/#{webhook_id}/#{token}"
          Logger.info("Successfully created webhook #{webhook_id} in channel #{channel_id}")
          {:ok, %{created: true, webhook_id: webhook_id, token: token, url: url, name: name, channel_id: channel_id}}

        {:error, {status, %{"message" => message}}} ->
          {:error, {status, message}}

        {:error, error} ->
          {:error, error}
      end
    end
  end
end