defmodule Lux.Prisms.Discord.Guilds.CreateSticker do
  @moduledoc """
  A prism for uploading a custom sticker to a Discord server (guild).
  The sticker file must be:
  - Less than 512KB in size
  - PNG, APNG, GIF, or JPG/JPEG format
  - Recommended size: 320x320 pixels

  ## Examples
      iex> CreateSticker.handler(%{
      ...>   guild_id: "987654321",
      ...>   name: "my_cool_sticker",
      ...>   description: "A very cool sticker",
      ...>   tags: "happy,cool",
      ...>   file: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
      ...> }, %{name: "Agent"})
      {:ok, %{
        created: true,
        guild_id: "987654321",
        sticker: %{
          id: "123456789",
          name: "my_cool_sticker",
          description: "A very cool sticker",
          tags: "happy,cool",
          format_type: 1
        }
      }}
  """

  use Lux.Prism,
    name: "Create Discord Guild Sticker",
    description: "Uploads a custom sticker to a Discord server",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to create the sticker in",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "Name of the sticker (2-30 characters)",
          pattern: "^[\\w-]{2,30}$"
        },
        description: %{
          type: :string,
          description: "Description of the sticker (optional, empty or 2-100 characters)",
          pattern: "^$|^.{2,100}$"
        },
        tags: %{
          type: :string,
          description: "Comma-separated list of tags (keywords) for the sticker",
          pattern: "^[\\w-,]{1,200}$"
        },
        file: %{
          type: :string,
          description: "Base64 encoded file data (PNG, APNG, GIF, or JPG/JPEG, max 512KB)",
          pattern: "^data:image\\/(png|apng|gif|jpe?g);base64,[A-Za-z0-9+/=]+$"
        }
      },
      required: [:guild_id, :name, :tags, :file]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{
          type: :boolean,
          description: "Whether the sticker was successfully created"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild where the sticker was created"
        },
        sticker: %{
          type: :object,
          description: "Information about the created sticker",
          properties: %{
            id: %{
              type: :string,
              description: "The ID of the created sticker"
            },
            name: %{
              type: :string,
              description: "The name of the sticker"
            },
            description: %{
              type: :string,
              description: "The description of the sticker (optional)"
            },
            tags: %{
              type: :string,
              description: "Comma-separated list of tags"
            },
            format_type: %{
              type: :integer,
              description: "The format type of the sticker (1: PNG, 2: APNG, 3: GIF, 4: JPG/JPEG)"
            }
          }
        }
      },
      required: [:created, :guild_id, :sticker]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @max_size 524_288  # 512KB in bytes

  @doc """
  Handles the request to create a custom sticker in a Discord server.

  Returns {:ok, %{created: true, guild_id: guild_id, sticker: sticker_data}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, name} <- validate_param(params, :name),
         {:ok, tags} <- validate_param(params, :tags),
         {:ok, file} <- validate_param(params, :file),
         {:ok, description} <- validate_optional_param(params, :description),
         {:ok, file_size} <- validate_file_size(file),
         {:ok, format_type} <- get_format_type(file) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating sticker '#{name}' in guild #{guild_id} (file size: #{file_size} bytes)")

      path = "/guilds/#{guild_id}/stickers"
      body = %{
        "name" => name,
        "tags" => tags,
        "file" => file
      }
      |> maybe_add_description(description)

      plug = Map.get(params, :plug)
      opts = %{
        json: body,
        plug: plug
      }
      |> Map.reject(fn {_k, v} -> is_nil(v) end)

      case Client.request(:post, path, opts) do
        {:ok, response} ->
          Logger.info("Successfully created sticker '#{name}' in guild #{guild_id}")
          {:ok, %{
            created: true,
            guild_id: guild_id,
            sticker: %{
              id: response["id"],
              name: response["name"],
              description: response["description"],
              tags: response["tags"],
              format_type: format_type
            }
          }}
        {:error, error} ->
          Logger.error("Failed to create sticker '#{name}' in guild #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) when is_atom(key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_optional_param(params, key) when is_atom(key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      :error -> {:ok, nil}
      _ -> {:error, "Invalid #{key}"}
    end
  end

  defp maybe_add_description(body, nil), do: body
  defp maybe_add_description(body, description), do: Map.put(body, "description", description)

  defp validate_file_size(file) do
    case String.split(file, ",") do
      [_header, base64_data] ->
        size = byte_size(Base.decode64!(base64_data))
        if size <= @max_size do
          {:ok, size}
        else
          {:error, "File size #{size} bytes exceeds maximum of #{@max_size} bytes (512KB)"}
        end
      _ ->
        {:error, "Invalid file data format"}
    end
  end

  defp get_format_type(file) do
    case Regex.run(~r/^data:image\/(png|apng|gif|jpe?g);base64,/, file) do
      ["data:image/png;base64," | _] -> {:ok, 1}  # PNG
      ["data:image/apng;base64," | _] -> {:ok, 2}  # APNG
      ["data:image/gif;base64," | _] -> {:ok, 3}  # GIF
      ["data:image/jpeg;base64," | _] -> {:ok, 4}  # JPEG
      ["data:image/jpg;base64," | _] -> {:ok, 4}  # JPG
      _ -> {:error, "Invalid file format"}
    end
  end
end
