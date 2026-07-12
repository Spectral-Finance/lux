defmodule Lux.Prisms.Discord.ChannelManagementPrism do
  @moduledoc """
  A prism for managing Discord channels.
  Supports creating, updating (including archiving and permissions), deleting, and fetching channels.
  """
  use Lux.Prism,
    name: "Discord Channel Management",
    description: "Handles Discord channel operations including CRUD and permissions.",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["create", "update", "delete", "get"],
          description: "The action to perform."
        },
        guild_id: %{
          type: :string,
          description: "The guild ID (required for create)."
        },
        channel_id: %{
          type: :string,
          description: "The channel ID (required for update, delete, get)."
        },
        name: %{
          type: :string,
          description: "Channel name (for create/update)."
        },
        type: %{
          type: :integer,
          description: "Channel type (for create)."
        },
        archived: %{
          type: :boolean,
          description: "Whether the thread/channel is archived (for update)."
        },
        permission_overwrites: %{
          type: :array,
          items: %{type: :object},
          description: "Permissions to set (for create/update)."
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{
          type: :string,
          description: "Status of the operation."
        },
        data: %{
          type: :object,
          description: "Resulting channel data."
        }
      },
      required: ["status"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(params, _ctx) do
    with {:ok, action} <- fetch_param(params, :action) do

    case action do
      "create" -> create_channel(params)
      "update" -> update_channel(params)
      "delete" -> delete_channel(params)
      "get" -> get_channel(params)
      _ -> {:error, "Invalid action"}
    end
  end
  end

  defp create_channel(params) do
    case fetch_param(params, :guild_id) do
      {:ok, guild_id} ->
        payload = normalize_keys(params, [:name, :type, :permission_overwrites])
        with_retry(fn ->
          Client.request(:post, "/guilds/#{guild_id}/channels", %{json: payload})
        end)
        |> format_response()

      {:error, _} ->
        {:error, "guild_id is required for create action"}
    end
  end

  defp update_channel(params) do
    case fetch_param(params, :channel_id) do
      {:ok, channel_id} ->
        payload = normalize_keys(params, [:name, :archived, :permission_overwrites])
        with_retry(fn ->
          Client.request(:patch, "/channels/#{channel_id}", %{json: payload})
        end)
        |> format_response()

      {:error, _} ->
        {:error, "channel_id is required for update action"}
    end
  end

  defp delete_channel(params) do
    case fetch_param(params, :channel_id) do
      {:ok, channel_id} ->
        with_retry(fn ->
          Client.request(:delete, "/channels/#{channel_id}")
        end)
        |> format_response()

      {:error, _} ->
        {:error, "channel_id is required for delete action"}
    end
  end

  defp get_channel(params) do
    case fetch_param(params, :channel_id) do
      {:ok, channel_id} ->
        with_retry(fn ->
          Client.request(:get, "/channels/#{channel_id}")
        end)
        |> format_response()

      {:error, _} ->
        {:error, "channel_id is required for get action"}
    end
  end

  defp format_response({:ok, body}) do
    {:ok, %{status: "success", data: body}}
  end

  defp format_response({:error, reason}), do: {:error, reason}

  defp with_retry(func, retries \\ 3) do
    case func.() do
      {:error, {429, _msg, retry_after}} when retries > 0 ->
        unless Application.get_env(:lux, :env) == :test do
          Process.sleep(trunc(retry_after * 1000))
        end
        with_retry(func, retries - 1)

      {:error, {429, _msg}} when retries > 0 ->
        unless Application.get_env(:lux, :env) == :test do
          Process.sleep(100)
        end
        with_retry(func, retries - 1)

      other ->
        other
    end
  end

  defp normalize_keys(params, allowed_keys) do
    Enum.reduce(allowed_keys, %{}, fn key, acc ->
      string_key = Atom.to_string(key)
      cond do
        Map.has_key?(params, key) -> Map.put(acc, key, Map.fetch!(params, key))
        Map.has_key?(params, string_key) -> Map.put(acc, key, Map.fetch!(params, string_key))
        true -> acc
      end
    end)
  end

  defp fetch_param(params, key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(params, key) -> {:ok, Map.fetch!(params, key)}
      Map.has_key?(params, string_key) -> {:ok, Map.fetch!(params, string_key)}
      true -> {:error, "#{string_key} is required"}
    end
  end
end
