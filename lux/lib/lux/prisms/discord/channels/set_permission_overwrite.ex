defmodule Lux.Prisms.Discord.Channels.SetPermissionOverwrite do
  @moduledoc """
  A prism for creating or updating Discord channel permission overwrites.

  This lets agents adapt channel-level role or member access without managing
  the entire guild role model.
  """

  use Lux.Prism,
    name: "Set Discord Channel Permission Overwrite",
    description: "Creates or updates a role or member permission overwrite for a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the Discord channel",
          pattern: "^[0-9]{17,20}$"
        },
        overwrite_id: %{
          type: :string,
          description: "The role or member ID for the permission overwrite",
          pattern: "^[0-9]{17,20}$"
        },
        type: %{
          type: :integer,
          description: "Overwrite type (0: role, 1: member)",
          enum: [0, 1]
        },
        allow: %{
          type: :string,
          description: "Bitwise permission string to allow",
          pattern: "^[0-9]+$"
        },
        deny: %{
          type: :string,
          description: "Bitwise permission string to deny",
          pattern: "^[0-9]+$"
        },
        reason: %{
          type: :string,
          description: "Optional audit-log reason"
        }
      },
      required: ["channel_id", "overwrite_id", "type", "allow", "deny"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{
          type: :boolean,
          description: "Whether the overwrite was created or updated"
        },
        channel_id: %{
          type: :string,
          description: "The channel where the overwrite was applied"
        },
        overwrite_id: %{
          type: :string,
          description: "The role or member ID used for the overwrite"
        },
        type: %{
          type: :integer,
          description: "Overwrite type (0: role, 1: member)"
        },
        allow: %{
          type: :string,
          description: "Allowed permission bitset"
        },
        deny: %{
          type: :string,
          description: "Denied permission bitset"
        }
      },
      required: ["updated", "channel_id", "overwrite_id", "type", "allow", "deny"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Creates or updates a Discord channel permission overwrite.

  Returns `{:ok, %{updated: true, ...}}` on Discord 2xx responses.
  Returns `{:error, reason}` on validation or API failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_snowflake(params, :channel_id),
         {:ok, overwrite_id} <- validate_snowflake(params, :overwrite_id),
         {:ok, type} <- validate_type(params),
         {:ok, allow} <- validate_permission_bits(params, :allow),
         {:ok, deny} <- validate_permission_bits(params, :deny) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} updating permission overwrite #{overwrite_id} on channel #{channel_id}")

      headers = audit_reason_headers(params[:reason])

      request_opts =
        %{
          json: %{
            type: type,
            allow: allow,
            deny: deny
          }
        }
        |> maybe_put_headers(headers)

      case Client.request(:put, "/channels/#{channel_id}/permissions/#{overwrite_id}", request_opts) do
        {:ok, _response} ->
          {:ok,
           %{
             updated: true,
             channel_id: channel_id,
             overwrite_id: overwrite_id,
             type: type,
             allow: allow,
             deny: deny
           }}

        {:error, error} ->
          Logger.error("Failed to update permission overwrite #{overwrite_id} on channel #{channel_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_snowflake(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_type(params) do
    case Map.fetch(params, :type) do
      {:ok, type} when type in [0, 1] -> {:ok, type}
      _ -> {:error, "Missing or invalid type"}
    end
  end

  defp validate_permission_bits(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) and value >= 0 -> {:ok, Integer.to_string(value)}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp audit_reason_headers(nil), do: []
  defp audit_reason_headers(""), do: []

  defp audit_reason_headers(reason) when is_binary(reason) do
    [{"X-Audit-Log-Reason", URI.encode_www_form(reason)}]
  end

  defp audit_reason_headers(_reason), do: []

  defp maybe_put_headers(opts, []), do: opts
  defp maybe_put_headers(opts, headers), do: Map.put(opts, :headers, headers)
end
