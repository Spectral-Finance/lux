defmodule Lux.Integrations.Discord.CoreOperationsTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Discord.CoreOperations

  describe "message_action/2" do
    test "builds create and edit message actions" do
      assert {:ok, create} =
               CoreOperations.message_action(:create, %{
                 channel_id: "123",
                 content: "hello",
                 nonce: "request-1",
                 idempotency_key: "send:123:request-1"
               })

      assert create.operation == :discord_message_create
      assert create.method == :post
      assert create.endpoint == "/channels/123/messages"
      assert create.payload == %{content: "hello", nonce: "request-1"}
      assert create.idempotency_key == "send:123:request-1"

      assert {:ok, edit} =
               CoreOperations.message_action(:edit, %{
                 channel_id: "123",
                 message_id: "456",
                 content: "updated"
               })

      assert edit.method == :patch
      assert edit.endpoint == "/channels/123/messages/456"
      assert edit.payload == %{content: "updated"}
    end

    test "builds delete and bulk delete message actions" do
      assert {:ok, delete} =
               CoreOperations.message_action(:delete, %{channel_id: "123", message_id: "456"})

      assert delete.method == :delete
      assert delete.endpoint == "/channels/123/messages/456"

      assert {:ok, bulk_delete} =
               CoreOperations.message_action(:bulk_delete, %{
                 channel_id: "123",
                 message_ids: ["1", "2"]
               })

      assert bulk_delete.method == :post
      assert bulk_delete.endpoint == "/channels/123/messages/bulk-delete"
      assert bulk_delete.payload == %{messages: ["1", "2"]}
    end
  end

  describe "channel_action/2" do
    test "builds channel create and permission overwrite actions" do
      assert {:ok, create} =
               CoreOperations.channel_action(:create, %{
                 guild_id: "guild-1",
                 name: "support",
                 type: 0,
                 rate_limit_per_user: 10
               })

      assert create.endpoint == "/guilds/guild-1/channels"
      assert create.payload == %{name: "support", type: 0, rate_limit_per_user: 10}

      assert {:ok, overwrite} =
               CoreOperations.channel_action(:permission_overwrite, %{
                 channel_id: "123",
                 overwrite_id: "role-1",
                 type: 0,
                 allow: "1024",
                 deny: "0"
               })

      assert overwrite.method == :put
      assert overwrite.endpoint == "/channels/123/permissions/role-1"
      assert overwrite.payload == %{type: 0, allow: "1024", deny: "0"}
    end
  end

  describe "moderation_action/2" do
    test "builds timeout, ban, unban, and warning actions" do
      assert {:ok, timeout} =
               CoreOperations.moderation_action(:timeout, %{
                 guild_id: "guild-1",
                 user_id: "user-1",
                 until: "2026-05-13T12:00:00Z",
                 reason: "flood"
               })

      assert timeout.endpoint == "/guilds/guild-1/members/user-1"
      assert timeout.payload.communication_disabled_until == "2026-05-13T12:00:00Z"
      assert timeout.payload.reason == "flood"

      assert {:ok, ban} =
               CoreOperations.moderation_action(:ban, %{
                 guild_id: "guild-1",
                 user_id: "user-1",
                 delete_message_seconds: 3600
               })

      assert ban.endpoint == "/guilds/guild-1/bans/user-1"
      assert ban.method == :put
      assert ban.payload.delete_message_seconds == 3600

      assert {:ok, unban} =
               CoreOperations.moderation_action(:unban, %{
                 guild_id: "guild-1",
                 user_id: "user-1",
                 reason: "appeal accepted"
               })

      assert unban.method == :delete
      assert unban.payload.reason == "appeal accepted"

      assert {:ok, warning} =
               CoreOperations.moderation_action(:warning, %{
                 guild_id: "guild-1",
                 user_id: "user-1",
                 reason: "caps",
                 severity: :low
               })

      assert warning.method == :local
      assert warning.endpoint == nil
      assert warning.payload.severity == :low
    end
  end

  describe "event_action/2" do
    test "builds scheduled event actions" do
      assert {:ok, create} =
               CoreOperations.event_action(:create, %{
                 guild_id: "guild-1",
                 name: "Office hours",
                 scheduled_start_time: "2026-05-13T12:00:00Z",
                 entity_type: 3,
                 privacy_level: 2
               })

      assert create.endpoint == "/guilds/guild-1/scheduled-events"
      assert create.payload.name == "Office hours"

      assert {:ok, delete} =
               CoreOperations.event_action(:delete, %{guild_id: "guild-1", event_id: "event-1"})

      assert delete.method == :delete
      assert delete.endpoint == "/guilds/guild-1/scheduled-events/event-1"
    end
  end

  describe "retry_plan/2" do
    test "classifies retryable and non-retryable responses" do
      assert CoreOperations.retry_plan({:ok, %{}}) == %{retry?: false, reason: :ok, delay_ms: 0}

      assert CoreOperations.retry_plan({:error, {429, %{"retry_after" => 1.5}}) == %{
               retry?: true,
               reason: :rate_limited,
               delay_ms: 1500
             }

      assert CoreOperations.retry_plan({:error, {503, "unavailable"}}, %{default_delay_ms: 250}) == %{
               retry?: true,
               reason: :transient_discord_error,
               delay_ms: 250
             }

      assert CoreOperations.retry_plan({:error, {403, "missing permissions"}}) == %{
               retry?: false,
               reason: :not_retryable,
               delay_ms: 0
             }
    end
  end

  describe "operation_event/3" do
    test "builds persistence-ready operation event envelopes" do
      occurred_at = ~U[2026-05-13 00:00:00Z]
      {:ok, action} = CoreOperations.message_action(:delete, %{channel_id: "123", message_id: "456"})

      event =
        CoreOperations.operation_event(action, :succeeded, %{
          actor_id: "agent-1",
          guild_id: "guild-1",
          channel_id: "123",
          target_id: "456",
          metadata: %{attempt: 1},
          occurred_at: occurred_at
        })

      assert event.operation == :discord_message_delete
      assert event.status == :succeeded
      assert event.method == :delete
      assert event.endpoint == "/channels/123/messages/456"
      assert event.actor_id == "agent-1"
      assert event.metadata.attempt == 1
      assert event.occurred_at == occurred_at
    end
  end
end
