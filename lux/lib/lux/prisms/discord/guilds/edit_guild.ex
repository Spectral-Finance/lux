defmodule Lux.Prisms.Discord.Guilds.EditGuild do
  @moduledoc """
  A prism for modifying Discord guild (server) settings.
  Allows updating basic server settings like name, icon, and verification settings.

  ## Examples
      iex> EditGuild.handler(%{
      ...>   guild_id: "987654321",
      ...>   name: "My Cool Server",
      ...>   icon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
      ...> }, %{name: "Agent"})
      {:ok, %{
        modified: true,
        guild_id: "987654321",
        guild: %{
          id: "987654321",
          name: "My Cool Server",
          icon: "abcdef123456..."
        }
      }}
  """

  use Lux.Prism,
    name: "Edit Discord Guild",
    description: "Modifies basic settings of a Discord server",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to modify",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "New name of the guild (2-100 characters)",
          pattern: "^.{2,100}$"
        },
        icon: %{
          type: :string,
          description: "Base64 encoded icon image (PNG, GIF, or JPEG)",
          pattern: "^data:image\\/(png|gif|jpe?g);base64,[A-Za-z0-9+/=]+$"
        },
        verification_level: %{
          type: :integer,
          description: "Verification level (optional)",
          enum: [0, 1, 2, 3, 4]
        },
        explicit_content_filter: %{
          type: :integer,
          description: "Explicit content filter level (optional)",
          enum: [0, 1, 2]
        },
        system_channel_id: %{
          type: :string,
          description: "ID of system message channel (optional)",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: [:guild_id]
    },
    output_schema: %{
      type: :object,
      properties: %{
        modified: %{
          type: :boolean,
          description: "Whether the guild was successfully modified"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the modified guild"
        },
        guild: %{
          type: :object,
          description: "Information about the modified guild",
          properties: %{
            id: %{
              type: :string,
              description: "The guild ID"
            },
            name: %{
              type: :string,
              description: "The guild name"
            },
            icon: %{
              type: :string,
              description: "The guild icon hash"
            },
            verification_level: %{
              type: :integer,
              description: "Verification level"
            },
            explicit_content_filter: %{
              type: :integer,
              description: "Explicit content filter level"
            },
            system_channel_id: %{
              type: :string,
              description: "ID of system message channel"
            }
          }
        }
      },
      required: [:modified, :guild_id, :guild]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to modify a Discord guild's settings.

  Returns {:ok, %{modified: true, guild_id: guild_id, guild: guild_data}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, body} <- build_request_body(params) do

      agent_name = agent[:name] || "Unknown Agent"
      changes = get_change_description(params)
      Logger.info("Agent #{agent_name} modifying guild #{guild_id} settings: #{changes}")

      path = "/guilds/#{guild_id}"
      plug = Map.get(params, :plug)
      opts = %{
        json: body,
        plug: plug
      }
      |> Map.reject(fn {_k, v} -> is_nil(v) end)

      case Client.request(:patch, path, opts) do
        {:ok, response} ->
          Logger.info("Successfully modified guild #{guild_id}")
          {:ok, %{
            modified: true,
            guild_id: guild_id,
            guild: response
          }}
        {:error, error} ->
          Logger.error("Failed to modify guild #{guild_id}: #{inspect(error)}")
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

  defp validate_enum_param(params, key, valid_values) when is_atom(key) do
    case Map.fetch(params, key) do
      {:ok, value} ->
        if value in valid_values do
          {:ok, value}
        else
          {:error, "Invalid #{key} value"}
        end
      :error -> {:ok, nil}
    end
  end

  defp build_request_body(params) do
    with {:ok, name} <- maybe_add_field(params, "name"),
         {:ok, icon} <- maybe_add_field(params, "icon"),
         {:ok, verification_level} <- validate_enum_param(params, :verification_level, [0, 1, 2, 3, 4]),
         {:ok, explicit_content_filter} <- validate_enum_param(params, :explicit_content_filter, [0, 1, 2]),
         {:ok, system_channel_id} <- maybe_add_field(params, "system_channel_id") do

      body = %{}
      |> add_if_present("name", name)
      |> add_if_present("icon", icon)
      |> add_if_present("verification_level", verification_level)
      |> add_if_present("explicit_content_filter", explicit_content_filter)
      |> add_if_present("system_channel_id", system_channel_id)

      if Enum.empty?(body) do
        {:error, "No valid fields to update"}
      else
        {:ok, body}
      end
    end
  end

  defp add_if_present(body, _field, nil), do: body
  defp add_if_present(body, field, value), do: Map.put(body, field, value)

  defp maybe_add_field(params, field) do
    case Map.get(params, String.to_atom(field)) do
      nil -> {:ok, nil}
      value -> {:ok, value}
    end
  end

  defp get_change_description(params) do
    params
    |> Map.drop([:guild_id, :plug])
    |> Enum.map_join(", ", fn {k, _v} -> "#{k}" end)
    |> case do
      "" -> "no changes"
      changes -> changes
    end
  end
end
