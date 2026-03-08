defmodule Lux.Integrations.Telegram.BenchmarkTest do
  @moduledoc """
  Performance benchmarks for Telegram Bot API integration.
  Measures rate limiter, webhook parsing, and message serialization throughput.
  """
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.RateLimiter
  alias Lux.Integrations.Telegram.WebhookHandler

  describe "Rate limiter throughput" do
    test "handles 10,000 acquire calls in under 1 second" do
      {:ok, pid} = RateLimiter.start_link(name: nil)

      {time_us, _} = :timer.tc(fn ->
        for i <- 1..10_000 do
          # Use different chat_ids to avoid actual rate limiting
          RateLimiter.acquire(pid, "chat_#{i}")
        end
      end)

      time_ms = time_us / 1000
      assert time_ms < 1000, "10k rate limiter calls should take <1s, got #{time_ms}ms"
    end
  end

  describe "Webhook update parsing" do
    test "parses 1,000 message updates within 100ms" do
      update = %{
        "update_id" => 123456,
        "message" => %{
          "message_id" => 1,
          "from" => %{"id" => 12345, "is_bot" => false, "first_name" => "Test", "username" => "testuser"},
          "chat" => %{"id" => -100123, "type" => "group", "title" => "Test Group"},
          "date" => 1_700_000_000,
          "text" => "/start hello world " <> String.duplicate("x", 200),
          "entities" => [%{"type" => "bot_command", "offset" => 0, "length" => 6}]
        }
      }

      {time_us, _} = :timer.tc(fn ->
        for _ <- 1..1000 do
          WebhookHandler.parse_update(update)
        end
      end)

      avg_us = time_us / 1000
      assert avg_us < 100, "Update parsing should take <100μs, got #{avg_us}μs"
    end

    test "parses callback_query updates efficiently" do
      update = %{
        "update_id" => 789,
        "callback_query" => %{
          "id" => "callback_123",
          "from" => %{"id" => 12345, "is_bot" => false, "first_name" => "User"},
          "message" => %{
            "message_id" => 5,
            "chat" => %{"id" => 12345, "type" => "private"},
            "date" => 1_700_000_000,
            "text" => "Choose an option"
          },
          "data" => "option_1"
        }
      }

      {time_us, _} = :timer.tc(fn ->
        for _ <- 1..1000 do
          WebhookHandler.parse_update(update)
        end
      end)

      avg_us = time_us / 1000
      assert avg_us < 100, "Callback parsing should take <100μs, got #{avg_us}μs"
    end
  end

  describe "Message serialization" do
    test "serializes SendMessage params within 0.1ms" do
      params = %{
        chat_id: 12345,
        text: "Hello! " <> String.duplicate("Test message. ", 50),
        parse_mode: "HTML",
        reply_markup: %{
          inline_keyboard: [
            [%{text: "Button 1", callback_data: "btn1"}, %{text: "Button 2", callback_data: "btn2"}],
            [%{text: "Button 3", url: "https://example.com"}]
          ]
        }
      }

      {time_us, _} = :timer.tc(fn ->
        for _ <- 1..1000 do
          Jason.encode!(params)
        end
      end)

      avg_us = time_us / 1000
      assert avg_us < 100, "Message serialization should take <0.1ms, got #{avg_us}μs"
    end
  end
end
