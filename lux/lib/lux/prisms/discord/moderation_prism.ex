defmodule Lux.Prisms.Discord.ModerationPrism do
  @moduledoc """
  A prism for managing Discord moderation actions.
  Supports user timeouts, bans, unbans, and kick operations.
  """
  use Lux.Prism,
    name: "Discord Moderation",
    description: "Handles Discord server moderation tasks such as ban, unban, timeout, and kick.",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["timeout", "ban", "unban", "kick"],
          description: "The moderation action to perform."
        },
        guild_id: %{
          type: :string,
          description: "The guild ID."
        },
        user_id: %{
          type: :string,
          description: "The user ID to moderate."
        },
        communication_disabled_until: %{
          type: :string,
          description: "ISO8601 timestamp for timeout (for timeout action, or null to remove)."
        },
        delete_message_seconds: %{
          type: :integer,
          description: "Number of seconds to delete messages (for ban)."
        },
        reason: %{
          type: :string,
          description: "Audit log reason."
        }
      },
      required: ["action", "guild_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{
          type: :string,
          description: "Status of the operation."
        }
      },
      required: ["status"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(params, _ctx) do
    with {:ok, action} <- fetch_param(params, :action),
         {:ok, guild_id} <- fetch_param(params, :guild_id),
         {:ok, user_id} <- fetch_param(params, :user_id) do

    case action do
      "timeout" -> timeout_user(guild_id, user_id, params)
      "ban" -> ban_user(guild_id, user_id, params)
      "unban" -> unban_user(guild_id, user_id)
      "kick" -> kick_user(guild_id, user_id)
      _ -> {:error, "Invalid action"}
    end
  end
  end

  defp timeout_user(guild_id, user_id, params) do
    payload = %{communication_disabled_until: get_param(params, :communication_disabled_until)}

    with_retry(fn ->
      Client.request(:patch, "/guilds/#{guild_id}/members/#{user_id}", %{json: payload})
    end)
    |> format_response(%{})
  end

  defp ban_user(guild_id, user_id, params) do
    delete_seconds =
      get_param(params, :delete_message_seconds) ||
        (get_param(params, :delete_message_days, 0) * 86_400)

    payload = %{delete_message_seconds: min(delete_seconds, 604_800)}

    opts = %{json: payload}
    opts = maybe_add_audit_reason(opts, get_param(params, :reason))

    with_retry(fn ->
      Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", opts)
    end)
    |> format_response(%{})
  end

  defp unban_user(guild_id, user_id) do
    with_retry(fn ->
      Client.request(:delete, "/guilds/#{guild_id}/bans/#{user_id}")
    end)
    |> format_response(%{})
  end

  defp kick_user(guild_id, user_id) do
    with_retry(fn ->
      Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}")
    end)
    |> format_response(%{})
  end

  defp format_response({:ok, body}) do
    body = if body == "", do: %{}, else: body
    {:ok, %{status: "success", data: body}}
  end

  defp format_response({:ok, _body}, default) do
    {:ok, %{status: "success", data: default}}
  end

  defp format_response({:error, reason}), do: {:error, reason}

  defp with_retry(func, retries \\ 3) do
    case func.() do
      {:error, {429, msg}} when retries > 0 ->
        unless Application.get_env(:lux, :env) == :test do
          delay =
            case msg do
              %{"retry_after" => r} when is_number(r) -> trunc(r * 1000)
              _ -> 100
            end
          Process.sleep(delay)
        end
        with_retry(func, retries - 1)

      other ->
        other
    end
  end

  defp maybe_add_audit_reason(opts, nil), do: opts
  defp maybe_add_audit_reason(opts, reason) do
    Map.put(opts, :headers, [{"X-Audit-Log-Reason", URI.encode(reason)}])
  end

  defp normalize_keys(params) do
    Map.new(params, fn
      {k, v} when is_binary(k) ->
        case safe_to_existing_atom(k) do
          nil -> {k, v}
          atom -> {atom, v}
        end
      {k, v} -> {k, v}
    end)
  end

  defp safe_to_existing_atom(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> nil
    end
  end

  defp fetch_param(params, key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(params, key) -> {:ok, Map.fetch!(params, key)}
      Map.has_key?(params, string_key) -> {:ok, Map.fetch!(params, string_key)}
      true -> {:error, "#{string_key} is required"}
    end
  end

  defp get_param(params, key, default \\ nil) do
    case fetch_param(params, key) do
      {:ok, value} -> value
      {:error, _} -> default
    end
  end
end
