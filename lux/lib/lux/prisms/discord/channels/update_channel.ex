defmodule Lux.Prisms.Discord.Channels.UpdateChannel do
  @moduledoc """
  A prism for updating Discord channel settings.
  """

  use Lux.Prism,
    name: "Update Discord Channel",
    description: "Updates mutable settings for a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to update",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{type: :string, description: "New channel name", minLength: 1, maxLength: 100},
        topic: %{type: :string, description: "New channel topic", maxLength: 1024},
        position: %{type: :integer, description: "Channel sort position"},
        nsfw: %{type: :boolean, description: "Whether the channel is NSFW"},
        rate_limit_per_user: %{
          type: :integer,
          description: "Seconds a user must wait before sending another message",
          minimum: 0,
          maximum: 21_600
        },
        parent_id: %{
          type: :string,
          description: "Category ID for the channel",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{type: :boolean, description: "Whether the channel was updated"},
        channel_id: %{type: :string, description: "Updated channel ID"},
        name: %{type: :string, description: "Updated channel name"},
        topic: %{type: :string, description: "Updated channel topic"},
        type: %{type: :integer, description: "Channel type"}
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @mutable_fields [:name, :topic, :position, :nsfw, :rate_limit_per_user, :parent_id]

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, body} <- build_body(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} updating channel #{channel_id}")

      case Client.request(:patch, "/channels/#{channel_id}", %{json: body}) do
        {:ok, channel} ->
          Logger.info("Successfully updated channel #{channel_id}")

          {:ok,
           %{
             updated: true,
             channel_id: channel["id"] || channel_id,
             name: channel["name"],
             topic: channel["topic"],
             type: channel["type"]
           }}

        error ->
          Logger.error("Failed to update channel #{channel_id}: #{inspect(error)}")
          error
      end
    end
  end

  defp build_body(params) do
    body =
      @mutable_fields
      |> Enum.filter(&Map.has_key?(params, &1))
      |> Enum.reject(&is_nil(params[&1]))
      |> Map.new(&{&1, params[&1]})

    case body do
      empty when empty == %{} -> {:error, "At least one channel field is required"}
      _ -> {:ok, body}
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
