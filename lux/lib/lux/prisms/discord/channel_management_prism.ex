defmodule Lux.Prisms.Discord.ChannelManagementPrism do
  @moduledoc """
  Core Prism for Discord channel management operations:
  - Channel creation and deletion
  - Configuration updates (topic, slowmode, bitrate)
  - Permission overwrites setup for roles and members
  - Channel listing and inspection
  """

  use Lux.Prism,
    name: "Discord Channel Management Prism",
    description: "Performs channel creation, modification, deletion, permission setup, and retrieval in Discord guilds",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "create_channel",
            "read_channel",
            "modify_channel",
            "delete_channel",
            "set_permissions",
            "list_channels"
          ],
          description: "Channel management action to perform"
        },
        payload: %{
          type: :object,
          description: "Action-specific parameters and options"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: :object}
      },
      required: ["action", "result"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action", "create_channel")
    payload = Map.get(input, :payload) || Map.get(input, "payload", %{})

    case execute_action(action, payload) do
      {:ok, result} ->
        {:ok, %{action: action, result: result}}

      {:error, reason} ->
        {:error, "ChannelManagementPrism error on '#{action}': #{inspect(reason)}"}
    end
  end

  defp execute_action("create_channel", payload) do
    guild_id = Map.get(payload, :guild_id, Map.get(payload, "guild_id"))
    name = Map.get(payload, :name, Map.get(payload, "name"))
    type = Map.get(payload, :type, Map.get(payload, "type", 0))
    topic = Map.get(payload, :topic, Map.get(payload, "topic"))
    slowmode = Map.get(payload, :rate_limit_per_user, Map.get(payload, "rate_limit_per_user"))
    opts = extract_client_opts(payload)

    body = %{"name" => name, "type" => type}
    body = if topic, do: Map.put(body, "topic", topic), else: body
    body = if slowmode, do: Map.put(body, "rate_limit_per_user", slowmode), else: body

    Client.request(:post, "/guilds/#{guild_id}/channels", Map.put(opts, :json, body))
  end

  defp execute_action("read_channel", payload) do
    channel_id = Map.get(payload, :channel_id, Map.get(payload, "channel_id"))
    opts = extract_client_opts(payload)
    Client.request(:get, "/channels/#{channel_id}", opts)
  end

  defp execute_action("modify_channel", payload) do
    channel_id = Map.get(payload, :channel_id, Map.get(payload, "channel_id"))
    opts = extract_client_opts(payload)

    body =
      payload
      |> Map.take([:name, :topic, :rate_limit_per_user, :archived, "name", "topic", "rate_limit_per_user", "archived"])

    Client.request(:patch, "/channels/#{channel_id}", Map.put(opts, :json, body))
  end

  defp execute_action("delete_channel", payload) do
    channel_id = Map.get(payload, :channel_id, Map.get(payload, "channel_id"))
    opts = extract_client_opts(payload)

    case Client.request(:delete, "/channels/#{channel_id}", opts) do
      {:ok, res} -> {:ok, %{deleted: true, channel: res}}
      error -> error
    end
  end

  defp execute_action("set_permissions", payload) do
    channel_id = Map.get(payload, :channel_id, Map.get(payload, "channel_id"))
    overwrite_id = Map.get(payload, :overwrite_id, Map.get(payload, "overwrite_id"))
    type = Map.get(payload, :type, Map.get(payload, "type", 0))
    allow = Map.get(payload, :allow, Map.get(payload, "allow", "0"))
    deny = Map.get(payload, :deny, Map.get(payload, "deny", "0"))
    opts = extract_client_opts(payload)

    body = %{"type" => type, "allow" => to_string(allow), "deny" => to_string(deny)}
    case Client.request(:put, "/channels/#{channel_id}/permissions/#{overwrite_id}", Map.put(opts, :json, body)) do
      {:ok, _} -> {:ok, %{status: :ok, overwrite_id: overwrite_id}}
      error -> error
    end
  end

  defp execute_action("list_channels", payload) do
    guild_id = Map.get(payload, :guild_id, Map.get(payload, "guild_id"))
    opts = extract_client_opts(payload)
    Client.request(:get, "/guilds/#{guild_id}/channels", opts)
  end

  defp execute_action(unknown, _payload) do
    {:error, "Unknown action: #{unknown}"}
  end

  defp extract_client_opts(payload) do
    opts = %{}

    opts =
      case Map.get(payload, :token, Map.get(payload, "token")) do
        nil -> opts
        token -> Map.put(opts, :token, token)
      end

    case Map.get(payload, :plug, Map.get(payload, "plug")) do
      nil -> opts
      plug -> Map.put(opts, :plug, plug)
    end
  end
end
