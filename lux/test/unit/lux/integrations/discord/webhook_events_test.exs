defmodule Lux.Integrations.Discord.WebhookEventsTest do
  @moduledoc """
  Tests for the Discord WebhookEvents integration module.
  """

  use UnitAPICase, async: true

  alias Lux.Integrations.Discord.WebhookEvents

  describe "new_trigger/1" do
    test "creates trigger with required fields" do
      trigger = WebhookEvents.new_trigger(
        name: "test",
        webhook_url: "https://discord.com/api/webhooks/123/token"
      )

      assert trigger.name == "test"
      assert trigger.webhook_url == "https://discord.com/api/webhooks/123/token"
      assert trigger.filter == %{}
      assert trigger.rate_limit_ms == 0
      assert trigger.last_executed_at == nil
    end

    test "creates trigger with all options" do
      format_fn = fn _e -> %{content: "hello"} end

      trigger = WebhookEvents.new_trigger(
        name: "greeting",
        webhook_url: "https://discord.com/api/webhooks/123/token",
        filter: %{type: :member_join},
        format_fn: format_fn,
        rate_limit_ms: 5000
      )

      assert trigger.name == "greeting"
      assert trigger.filter == %{type: :member_join}
      assert trigger.format_fn == format_fn
      assert trigger.rate_limit_ms == 5000
    end

    test "raises when webhook_url is missing" do
      assert_raise KeyError, fn ->
        WebhookEvents.new_trigger(name: "test")
      end
    end
  end

  describe "matches?/2" do
    test "matches when filter is empty" do
      assert WebhookEvents.matches?(%{type: :message}, %{})
    end

    test "matches when all filter keys match" do
      event = %{type: :message, user_id: "u1", channel_id: "c1"}
      assert WebhookEvents.matches?(event, %{type: :message})
      assert WebhookEvents.matches?(event, %{type: :message, user_id: "u1"})
    end

    test "does not match when filter values differ" do
      event = %{type: :message, user_id: "u1"}
      refute WebhookEvents.matches?(event, %{type: :voice})
      refute WebhookEvents.matches?(event, %{type: :message, user_id: "u2"})
    end

    test "matches with string keys in event" do
      event = %{"type" => :message, "user_id" => "u1"}
      assert WebhookEvents.matches?(event, %{type: :message})
    end

    test "handles nil event values" do
      event = %{type: :message, channel_id: nil}
      refute WebhookEvents.matches?(event, %{channel_id: "c1"})
    end
  end

  describe "rate_limited?/2" do
    test "not limited when rate_limit_ms is 0" do
      trigger = %{rate_limit_ms: 0, last_executed_at: DateTime.utc_now()}
      refute WebhookEvents.rate_limited?(trigger, DateTime.utc_now())
    end

    test "not limited when never executed" do
      trigger = %{rate_limit_ms: 5000, last_executed_at: nil}
      refute WebhookEvents.rate_limited?(trigger, DateTime.utc_now())
    end

    test "limited when within rate limit window" do
      now = DateTime.utc_now()
      trigger = %{rate_limit_ms: 5000, last_executed_at: now}
      assert WebhookEvents.rate_limited?(trigger, DateTime.add(now, 3, :second))
    end

    test "not limited when past rate limit window" do
      now = DateTime.utc_now()
      trigger = %{rate_limit_ms: 5000, last_executed_at: now}
      refute WebhookEvents.rate_limited?(trigger, DateTime.add(now, 6, :second))
    end
  end

  describe "process/3" do
    test "skips events that don't match filter" do
      trigger = WebhookEvents.new_trigger(
        name: "test",
        webhook_url: "https://discord.com/api/webhooks/123/token",
        filter: %{type: :voice}
      )

      events = [%{type: :message, user_id: "u1", metadata: %{}}]
      result = WebhookEvents.process([trigger], events, %{})

      assert result.executed == []
      assert length(result.skipped) == 1
      assert hd(result.skipped).reason == :no_match
      assert result.errors == []
    end

    test "skips rate-limited triggers" do
      now = DateTime.utc_now()

      trigger =
        WebhookEvents.new_trigger(
          name: "rate-test",
          webhook_url: "https://discord.com/api/webhooks/123/token",
          filter: %{type: :message},
          rate_limit_ms: 60_000
        )
        |> Map.put(:last_executed_at, now)

      events = [%{type: :message, user_id: "u1", metadata: %{}}]
      result = WebhookEvents.process([trigger], events, %{})

      assert result.executed == []
      assert length(result.skipped) == 1
      assert hd(result.skipped).reason == :rate_limited
    end

    test "uses default format function when none provided" do
      trigger = WebhookEvents.new_trigger(
        name: "default-fmt",
        webhook_url: "https://discord.com/api/webhooks/123/token"
      )

      # Just verify it doesn't crash with default format
      assert is_function(trigger.format_fn, 1)
      result = trigger.format_fn.(%{type: :test, metadata: %{content: "hello"}})
      assert result == %{content: "hello"}
    end
  end
end
