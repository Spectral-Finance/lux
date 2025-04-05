defmodule Lux.Prisms.Discord.Guilds.CreateEmoji do
  @moduledoc """
  A prism for uploading a custom emoji to a Discord server (guild).
  The emoji image must be:
  - Less than 256KB in size
  - PNG, JPEG, GIF, or WebP format
  - Recommended minimum size: 128x128 pixels

  ## Examples
      iex> CreateEmoji.handler(%{
      ...>   guild_id: "987654321",
      ...>   name: "my_cool_emoji",
      ...>   image: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
      ...> }, %{name: "Agent"})
      {:ok, %{
        created: true,
        guild_id: "987654321",
        emoji: %{
          id: "123456789",
          name: "my_cool_emoji",
          animated: false
        }
      }}
  """

  use Lux.Prism,
    name: "Create Discord Guild Emoji",
    description: "Uploads a custom emoji to a Discord server",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to create the emoji in",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "Name of the emoji (2-32 characters)",
          pattern: "^[\\w_]{2,32}$"
        },
        image: %{
          type: :string,
          description: "Base64 encoded image data (PNG, JPEG, GIF, or WebP, max 256KB)",
          pattern: "^data:image\\/(png|jpeg|gif|webp);base64,[A-Za-z0-9+/=]+$"
        }
      },
      required: ["guild_id", "name", "image"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{
          type: :boolean,
          description: "Whether the emoji was successfully created"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild where the emoji was created"
        },
        emoji: %{
          type: :object,
          description: "Information about the created emoji",
          properties: %{
            id: %{
              type: :string,
              description: "The ID of the created emoji"
            },
            name: %{
              type: :string,
              description: "The name of the emoji"
            },
            animated: %{
              type: :boolean,
              description: "Whether the emoji is animated (GIF)"
            }
          }
        }
      },
      required: ["created", "guild_id", "emoji"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @max_size 262_144  # 256KB in bytes

  @doc """
  Handles the request to create a custom emoji in a Discord server.

  Returns {:ok, %{created: true, guild_id: guild_id, emoji: emoji_data}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, name} <- validate_param(params, :name),
         {:ok, image} <- validate_param(params, :image),
         {:ok, image_size} <- validate_image_size(image) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating emoji '#{name}' in guild #{guild_id} (image size: #{image_size} bytes)")

      path = "/guilds/#{guild_id}/emojis"
      body = %{name: name, image: image}
      plug = Map.get(params, :plug)

      opts = %{
        json: body,
        plug: plug
      }
      |> Map.reject(fn {_k, v} -> is_nil(v) end)

      case Client.request(:post, path, opts) do
        {:ok, response} ->
          Logger.info("Successfully created emoji '#{name}' in guild #{guild_id}")
          {:ok, %{
            created: true,
            guild_id: guild_id,
            emoji: %{
              id: response["id"],
              name: response["name"],
              animated: response["animated"] || false
            }
          }}
        {:error, {status, %{"code" => 50_045}}} ->
          Logger.error("Failed to create emoji '#{name}' in guild #{guild_id}: Image file size exceeds maximum of 256KB")
          {:error, "Image file size exceeds maximum of 256KB"}
        {:error, {status, response}} when is_map(response) ->
          message = response["message"] || "Unknown error"
          Logger.error("Failed to create emoji '#{name}' in guild #{guild_id}: #{message}")
          {:error, message}
        {:error, :invalid_token} ->
          Logger.error("Failed to create emoji '#{name}' in guild #{guild_id}: Invalid Discord token")
          {:error, "Invalid Discord token"}
        {:error, %{message: message}} when is_binary(message) ->
          Logger.error("Failed to create emoji '#{name}' in guild #{guild_id}: #{message}")
          {:error, message}
        error ->
          Logger.error("Failed to create emoji '#{name}' in guild #{guild_id}: #{inspect(error)}")
          {:error, "Unknown error occurred"}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_image_size(image) do
    # Extract base64 data after the comma
    case String.split(image, ",") do
      [_header, base64_data] ->
        size = byte_size(Base.decode64!(base64_data))
        if size <= @max_size do
          {:ok, size}
        else
          {:error, "Image size #{size} bytes exceeds maximum of #{@max_size} bytes (256KB)"}
        end
      _ ->
        {:error, "Invalid image data format"}
    end
  end
end
