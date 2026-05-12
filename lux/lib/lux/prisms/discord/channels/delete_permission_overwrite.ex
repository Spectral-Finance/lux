defmodule Lux.Prisms.Discord.Channels.DeletePermissionOverwrite do
  @moduledoc """
  A prism for deleting Discord channel permission overwrites.
  """

  use Lux.Prism,
    name: "Delete Discord Channel Permission Overwrite",
    description: "Deletes a role or member permission overwrite from a Discord channel",
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
        reason: %{
          type: :string,
          description: "Optional audit-log reason"
        }
      },
      required: ["channel_id", "overwrite_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{
          type: :boolean,
          description: "Whether the overwrite was deleted"
        },
        channel_id: %{
          type: :string,
          description: "The channel where the overwrite was deleted"
        },
        overwrite_id: %{
          type: :string,
          description: "The deleted role or member overwrite ID"
        }
      },
      required: ["deleted", "channel_id", "overwrite_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Deletes a Discord channel permission overwrite.

  Returns `{:ok, %{deleted: true, ...}}` on Discord 2xx responses.
  Returns `{:error, reason}` on validation or API failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_snowflake(params, :channel_id),
         {:ok, overwrite_id} <- validate_snowflake(params, :overwrite_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} deleting permission overwrite #{overwrite_id} on channel #{channel_id}")

      request_opts =
        params[:reason]
        |> audit_reason_headers()
        |> build_request_opts()

      case Client.request(:delete, "/channels/#{channel_id}/permissions/#{overwrite_id}", request_opts) do
        {:ok, _response} ->
          {:ok, %{deleted: true, channel_id: channel_id, overwrite_id: overwrite_id}}

        {:error, error} ->
          Logger.error("Failed to delete permission overwrite #{overwrite_id} on channel #{channel_id}: #{inspect(error)}")
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

  defp audit_reason_headers(nil), do: []
  defp audit_reason_headers(""), do: []

  defp audit_reason_headers(reason) when is_binary(reason) do
    [{"X-Audit-Log-Reason", URI.encode_www_form(reason)}]
  end

  defp audit_reason_headers(_reason), do: []

  defp build_request_opts([]), do: %{}
  defp build_request_opts(headers), do: %{headers: headers}
end
