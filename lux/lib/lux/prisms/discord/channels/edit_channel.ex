defmodule Lux.Prisms.Discord.Channels.EditChannel do
  @moduledoc """
  A prism for modifying Discord channel settings.

  This prism allows you to edit various channel settings including:
  - Channel name
  - Channel topic
  - Bitrate (for voice channels)
  - User limit (for voice channels)
  - NSFW flag

  ## Examples

      iex> EditChannel.handler(%{
      ...>   "channel_id" => "123456789012345678",
      ...>   "name" => "new-channel-name",
      ...>   "topic" => "New channel topic"
      ...> }, %{})
      {:ok, %{
        channel_id: "123456789012345678",
        name: "new-channel-name",
        topic: "New channel topic",
        edited: true
      }}

  """

  use Lux.Prism
  alias Lux.Integrations.Discord.Client
  require Logger

  def input_schema do
    %{
      "type" => "object",
      "required" => ["channel_id"],
      "properties" => %{
        "channel_id" => %{
          "type" => "string",
          "pattern" => "^\\d{17,20}$",
          "description" => "The ID of the channel to edit"
        },
        "name" => %{
          "type" => "string",
          "minLength" => 1,
          "maxLength" => 100,
          "description" => "New name of the channel"
        },
        "topic" => %{
          "type" => "string",
          "maxLength" => 1024,
          "description" => "New topic of the channel"
        },
        "bitrate" => %{
          "type" => "integer",
          "minimum" => 8000,
          "description" => "Voice channel bitrate (bits per second)"
        },
        "user_limit" => %{
          "type" => "integer",
          "minimum" => 0,
          "description" => "Maximum number of users in a voice channel"
        },
        "nsfw" => %{
          "type" => "boolean",
          "description" => "Whether the channel is NSFW"
        }
      }
    }
  end

  def output_schema do
    %{
      "type" => "object",
      "required" => ["channel_id", "edited"],
      "properties" => %{
        "channel_id" => %{
          "type" => "string",
          "description" => "The ID of the edited channel"
        },
        "name" => %{
          "type" => "string",
          "description" => "Updated channel name"
        },
        "topic" => %{
          "type" => "string",
          "description" => "Updated channel topic"
        },
        "edited" => %{
          "type" => "boolean",
          "description" => "Whether the channel was successfully edited"
        }
      }
    }
  end

  def handler(%{"channel_id" => channel_id} = params, _context) do
    Logger.info("Editing Discord channel #{channel_id}")

    json_params =
      params
      |> Map.take(["name", "topic", "bitrate", "user_limit", "nsfw"])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case Client.request(:patch, "/channels/#{channel_id}", %{json: json_params}) do
      {:ok, response} ->
        Logger.info("Successfully edited Discord channel #{channel_id}")

        {:ok,
         %{
           channel_id: response["id"],
           name: response["name"],
           topic: response["topic"],
           edited: true
         }}

      {:error, {status, message}} ->
        Logger.warning("Failed to edit Discord channel #{channel_id}: #{status} - #{message}")
        {:error, {status, message}}
    end
  end
end
