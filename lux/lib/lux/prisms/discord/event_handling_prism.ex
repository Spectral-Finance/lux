defmodule Lux.Prisms.Discord.EventHandlingPrism do
  @moduledoc """
  A prism for managing Discord scheduled events.
  Supports creating, updating, and fetching events.
  """
  use Lux.Prism,
    name: "Discord Event Handling",
    description: "Handles Discord server scheduled events and notifications.",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["create", "update", "delete", "list"],
          description: "The action to perform."
        },
        guild_id: %{
          type: :string,
          description: "The guild ID."
        },
        event_id: %{
          type: :string,
          description: "The scheduled event ID (for update, delete)."
        },
        name: %{
          type: :string,
          description: "Event name."
        },
        privacy_level: %{
          type: :integer,
          description: "Privacy level of the event (2 for GUILD_ONLY)."
        },
        scheduled_start_time: %{
          type: :string,
          description: "ISO8601 start time."
        },
        scheduled_end_time: %{
          type: :string,
          description: "ISO8601 end time."
        },
        description: %{
          type: :string,
          description: "Event description."
        },
        entity_type: %{
          type: :integer,
          description: "Type of the event (1 for STAGE_INSTANCE, 2 for VOICE, 3 for EXTERNAL)."
        },
        channel_id: %{
          type: :string,
          description: "Channel ID (required for STAGE_INSTANCE and VOICE)."
        },
        entity_metadata: %{
          type: :object,
          description: "Metadata for external events (e.g. location)."
        }
      },
      required: ["action", "guild_id"]
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
          description: "Resulting event data."
        }
      },
      required: ["status"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(params, _ctx) do
    with {:ok, action} <- fetch_param(params, :action),
         {:ok, guild_id} <- fetch_param(params, :guild_id) do

    case action do
      "create" -> create_event(guild_id, params)
      "update" -> update_event(guild_id, params)
      "delete" -> delete_event(guild_id, params)
      "list" -> list_events(guild_id)
      _ -> {:error, "Invalid action"}
    end
  end
  end

  defp create_event(guild_id, params) do
    payload = normalize_keys(params, [
      :name, :privacy_level, :scheduled_start_time, :scheduled_end_time,
      :description, :entity_type, :channel_id, :entity_metadata
    ])

    with_retry(fn ->
      Client.request(:post, "/guilds/#{guild_id}/scheduled-events", %{json: payload})
    end)
    |> format_response()
  end

  defp update_event(guild_id, params) do
    case fetch_param(params, :event_id) do
      {:ok, event_id} ->
        payload = normalize_keys(params, [
          :name, :privacy_level, :scheduled_start_time, :scheduled_end_time,
          :description, :entity_type, :channel_id, :entity_metadata
        ])

        with_retry(fn ->
          Client.request(:patch, "/guilds/#{guild_id}/scheduled-events/#{event_id}", %{json: payload})
        end)
        |> format_response()

      {:error, _} ->
        {:error, "event_id is required for update action"}
    end
  end

  defp delete_event(guild_id, params) do
    case fetch_param(params, :event_id) do
      {:ok, event_id} ->
        with_retry(fn ->
          Client.request(:delete, "/guilds/#{guild_id}/scheduled-events/#{event_id}")
        end)
        |> format_response(%{})

      {:error, _} ->
        {:error, "event_id is required for delete action"}
    end
  end

  defp list_events(guild_id) do
    with_retry(fn ->
      Client.request(:get, "/guilds/#{guild_id}/scheduled-events")
    end)
    |> format_response()
  end

  defp format_response({:ok, body}) do
    body = if body == "", do: %{}, else: body
    body = if is_list(body), do: %{events: body}, else: body
    {:ok, %{status: "success", data: body}}
  end
  defp format_response({:error, reason}), do: {:error, reason}

  defp format_response({:ok, _body}, default) do
    {:ok, %{status: "success", data: default}}
  end
  defp format_response({:error, reason}, _default), do: {:error, reason}

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
