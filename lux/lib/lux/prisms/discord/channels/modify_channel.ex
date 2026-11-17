defmodule Lux.Prisms.Discord.Channels.ModifyChannel do
  @moduledoc """
  A prism for modifying a Discord channel's settings.

  Supports updating channel name, topic, NSFW flag, position, slowmode,
  bitrate (voice), and user limit (voice).

  ## Examples
      iex> ModifyChannel.handler(%{
      ...>   channel_id: "123456789",
      ...>   name: "new-name",
      ...>   topic: "Updated topic"
      ...> }, %{name: "Agent"})
      {:ok, %{
        modified: true,
        channel_id: "123456789",
        name: "new-name"
      }}
  """

  use Lux.Prism,
    name: "Modify Discord Channel",
    description: "Modifies a Discord channel's settings",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to modify",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "New channel name (1-100 characters)",
          minLength: 1,
          maxLength: 100
        },
        topic: %{
          type: :string,
          description: "New channel topic (0-1024 characters for text, 0-4096 for forum)",
          maxLength: 4096
        },
        nsfw: %{
          type: :boolean,
          description: "Whether the channel is NSFW"
        },
        position: %{
          type: :integer,
          description: "Sorting position of the channel"
        },
        rate_limit_per_user: %{
          type: :integer,
          description: "Slowmode rate limit in seconds (0-21600)",
          minimum: 0,
          maximum: 21600
        },
        bitrate: %{
          type: :integer,
          description: "Bitrate for voice channels (8000-96000, or up to 128000 for VIP)"
        },
        user_limit: %{
          type: :integer,
          description: "User limit for voice channels (0-99, 0 means no limit)",
          minimum: 0,
          maximum: 99
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        modified: %{
          type: :boolean,
          description: "Whether the channel was successfully modified"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the modified channel"
        },
        name: %{
          type: :string,
          description: "The name of the modified channel"
        }
      },
      required: ["modified"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @optional_fields ~w(name topic nsfw position rate_limit_per_user bitrate user_limit)a

  @doc """
  Handles the request to modify a Discord channel.

  Returns {:ok, %{modified: true, channel_id: id, name: name}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} modifying channel #{channel_id}")

      body = Map.take(params, @optional_fields) |> Map.reject(fn {_k, v} -> is_nil(v) end)

      case Client.request(:patch, "/channels/#{channel_id}", %{json: body}) do
        {:ok, %{"id" => id, "name" => name}} ->
          Logger.info("Successfully modified channel #{id}")
          {:ok, %{modified: true, channel_id: id, name: name}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to modify channel #{channel_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to modify channel #{channel_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
