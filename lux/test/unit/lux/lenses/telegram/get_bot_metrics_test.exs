defmodule Lux.Lenses.Telegram.GetBotMetricsTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Telegram.GetBotMetrics

  setup do
    Req.Test.stub(Lux.Telegram.WebhookInfoMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => %{
        "url" => "https://bot.example.com/webhook",
        "has_custom_certificate" => false,
        "pending_update_count" => 3,
        "last_error_date" => nil,
        "last_error_message" => nil,
        "max_connections" => 40,
        "ip_address" => "1.2.3.4"
      }})
    end)

    Req.Test.stub(Lux.Telegram.GetMeMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => %{
        "id" => 123456, "username" => "test_bot", "first_name" => "TestBot",
        "can_join_groups" => true, "can_read_all_group_messages" => false,
        "supports_inline_queries" => true
      }})
    end)
    :ok
  end

  test "webhook_info" do
    {:ok, info} = GetBotMetrics.focus(%{action: "webhook_info", token: "t", plug: {Req.Test, Lux.Telegram.WebhookInfoMock}})
    assert info.url == "https://bot.example.com/webhook"
    assert info.pending_update_count == 3
  end

  test "bot_info" do
    {:ok, info} = GetBotMetrics.focus(%{action: "bot_info", token: "t", plug: {Req.Test, Lux.Telegram.GetMeMock}})
    assert info.username == "test_bot"
    assert info.supports_inline_queries == true
  end
end
