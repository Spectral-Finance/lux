defmodule Lux.Integrations.Discord.CoreOperations do
  @moduledoc """
  Shared Discord operation planning helpers for core server workflows.

  Existing Discord prisms/lenses can use these helpers to build consistent
  action plans, retry metadata, and audit/event envelopes for message,
  channel, moderation, and scheduled-event operations.
  """

  @type action_plan :: %{
          method: atom(),
          endpoint: String.t() | nil,
          payload: map(),
          operation: atom(),
          idempotency_key: String.t() | nil
        }

  @doc """
  Builds action plans for Discord message-management operations.
  """
  @spec message_action(atom(), map()) :: {:ok, action_plan()} | {:error, String.t()}
  def message_action(:create, %{channel_id: channel_id} = attrs) do
    payload =
      attrs
      |> take_payload([:content, :embeds, :components, :allowed_mentions, :message_reference])
      |> put_optional(:nonce, value(attrs, :nonce))

    {:ok, action(:discord_message_create, :post, "/channels/#{channel_id}/messages", payload, attrs)}
  end

  def message_action(:edit, %{channel_id: channel_id, message_id: message_id} = attrs) do
    payload = take_payload(attrs, [:content, :embeds, :components, :allowed_mentions])
    {:ok, action(:discord_message_edit, :patch, "/channels/#{channel_id}/messages/#{message_id}", payload, attrs)}
  end

  def message_action(:delete, %{channel_id: channel_id, message_id: message_id} = attrs) do
    {:ok, action(:discord_message_delete, :delete, "/channels/#{channel_id}/messages/#{message_id}", %{}, attrs)}
  end

  def message_action(:bulk_delete, %{channel_id: channel_id, message_ids: message_ids} = attrs)
      when is_list(message_ids) do
    payload = %{messages: message_ids}
    {:ok, action(:discord_message_bulk_delete, :post, "/channels/#{channel_id}/messages/bulk-delete", payload, attrs)}
  end

  def message_action(operation, _attrs), do: {:error, "Unsupported Discord message operation: #{operation}"}

  @doc """
  Builds action plans for Discord channel-management operations.
  """
  @spec channel_action(atom(), map()) :: {:ok, action_plan()} | {:error, String.t()}
  def channel_action(:create, %{guild_id: guild_id} = attrs) do
    payload = take_payload(attrs, [:name, :type, :topic, :parent_id, :position, :permission_overwrites, :rate_limit_per_user])
    {:ok, action(:discord_channel_create, :post, "/guilds/#{guild_id}/channels", payload, attrs)}
  end

  def channel_action(:edit, %{channel_id: channel_id} = attrs) do
    payload = take_payload(attrs, [:name, :topic, :position, :parent_id, :permission_overwrites, :rate_limit_per_user, :archived])
    {:ok, action(:discord_channel_edit, :patch, "/channels/#{channel_id}", payload, attrs)}
  end

  def channel_action(:delete, %{channel_id: channel_id} = attrs) do
    {:ok, action(:discord_channel_delete, :delete, "/channels/#{channel_id}", %{}, attrs)}
  end

  def channel_action(:permission_overwrite, %{channel_id: channel_id, overwrite_id: overwrite_id} = attrs) do
    payload = take_payload(attrs, [:type, :allow, :deny])
    {:ok, action(:discord_channel_permission_overwrite, :put, "/channels/#{channel_id}/permissions/#{overwrite_id}", payload, attrs)}
  end

  def channel_action(operation, _attrs), do: {:error, "Unsupported Discord channel operation: #{operation}"}

  @doc """
  Builds action plans for Discord moderation operations.
  """
  @spec moderation_action(atom(), map()) :: {:ok, action_plan()} | {:error, String.t()}
  def moderation_action(:timeout, %{guild_id: guild_id, user_id: user_id} = attrs) do
    payload =
      %{communication_disabled_until: value(attrs, :until)}
      |> put_optional(:reason, value(attrs, :reason))

    {:ok, action(:discord_member_timeout, :patch, "/guilds/#{guild_id}/members/#{user_id}", payload, attrs)}
  end

  def moderation_action(:ban, %{guild_id: guild_id, user_id: user_id} = attrs) do
    payload =
      %{}
      |> put_optional(:delete_message_seconds, value(attrs, :delete_message_seconds))
      |> put_optional(:reason, value(attrs, :reason))

    {:ok, action(:discord_member_ban, :put, "/guilds/#{guild_id}/bans/#{user_id}", payload, attrs)}
  end

  def moderation_action(:unban, %{guild_id: guild_id, user_id: user_id} = attrs) do
    payload = %{} |> put_optional(:reason, value(attrs, :reason))
    {:ok, action(:discord_member_unban, :delete, "/guilds/#{guild_id}/bans/#{user_id}", payload, attrs)}
  end

  def moderation_action(:warning, attrs) do
    {:ok, action(:discord_member_warning, :local, nil, take_payload(attrs, [:guild_id, :user_id, :reason, :severity]), attrs)}
  end

  def moderation_action(operation, _attrs), do: {:error, "Unsupported Discord moderation operation: #{operation}"}

  @doc """
  Builds action plans for Discord scheduled events.
  """
  @spec event_action(atom(), map()) :: {:ok, action_plan()} | {:error, String.t()}
  def event_action(:create, %{guild_id: guild_id} = attrs) do
    payload =
      take_payload(attrs, [
        :name,
        :description,
        :scheduled_start_time,
        :scheduled_end_time,
        :privacy_level,
        :entity_type,
        :channel_id,
        :entity_metadata
      ])

    {:ok, action(:discord_event_create, :post, "/guilds/#{guild_id}/scheduled-events", payload, attrs)}
  end

  def event_action(:delete, %{guild_id: guild_id, event_id: event_id} = attrs) do
    {:ok, action(:discord_event_delete, :delete, "/guilds/#{guild_id}/scheduled-events/#{event_id}", %{}, attrs)}
  end

  def event_action(operation, _attrs), do: {:error, "Unsupported Discord event operation: #{operation}"}

  @doc """
  Classifies a Discord API result for retry/backoff decisions.
  """
  @spec retry_plan({:ok, term()} | {:error, term()}, map()) :: map()
  def retry_plan(result, opts \\ %{})

  def retry_plan({:ok, _response}, _opts) do
    %{retry?: false, reason: :ok, delay_ms: 0}
  end

  def retry_plan({:error, {429, body}}, opts) do
    retry_after_ms =
      body
      |> value(:retry_after)
      |> retry_after_to_ms()

    %{retry?: true, reason: :rate_limited, delay_ms: retry_after_ms || value(opts, :default_delay_ms) || 1_000}
  end

  def retry_plan({:error, {status, _message}}, opts) when status in [500, 502, 503, 504] do
    %{retry?: true, reason: :transient_discord_error, delay_ms: value(opts, :default_delay_ms) || 1_000}
  end

  def retry_plan({:error, :timeout}, opts) do
    %{retry?: true, reason: :transport_timeout, delay_ms: value(opts, :default_delay_ms) || 1_000}
  end

  def retry_plan({:error, _error}, _opts) do
    %{retry?: false, reason: :not_retryable, delay_ms: 0}
  end

  @doc """
  Builds a stable event envelope for downstream persistence or emission.
  """
  @spec operation_event(action_plan(), atom(), map()) :: map()
  def operation_event(action_plan, status, attrs \\ %{}) do
    %{
      operation: action_plan.operation,
      status: status,
      endpoint: action_plan.endpoint,
      method: action_plan.method,
      idempotency_key: action_plan.idempotency_key,
      actor_id: value(attrs, :actor_id),
      guild_id: value(attrs, :guild_id),
      channel_id: value(attrs, :channel_id),
      target_id: value(attrs, :target_id),
      reason: value(attrs, :reason),
      metadata: value(attrs, :metadata) || %{},
      occurred_at: value(attrs, :occurred_at) || DateTime.utc_now()
    }
  end

  defp action(operation, method, endpoint, payload, attrs) do
    %{
      operation: operation,
      method: method,
      endpoint: endpoint,
      payload: payload,
      idempotency_key: value(attrs, :idempotency_key)
    }
  end

  defp take_payload(attrs, keys) do
    Enum.reduce(keys, %{}, fn key, acc ->
      put_optional(acc, key, value(attrs, key))
    end)
  end

  defp retry_after_to_ms(value) when is_integer(value), do: value * 1_000
  defp retry_after_to_ms(value) when is_float(value), do: round(value * 1_000)

  defp retry_after_to_ms(value) when is_binary(value) do
    case Float.parse(value) do
      {seconds, _rest} -> round(seconds * 1_000)
      :error -> nil
    end
  end

  defp retry_after_to_ms(_value), do: nil

  defp put_optional(map, _key, nil), do: map
  defp put_optional(map, key, value), do: Map.put(map, key, value)

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil
end
