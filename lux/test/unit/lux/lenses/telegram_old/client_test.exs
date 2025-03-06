defmodule Lux.Lenses.Telegram.ClientTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Telegram.Client
  alias Lux.Lenses.Telegram.RateLimiter

  setup do
    # Create a mock lens
    lens = %{
      url: "https://api.telegram.org/bot123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11/getMe",
      method: :post,
      headers: [{"Content-Type", "application/json"}]
    }

    # Reset rate limiters before each test
    RateLimiter.reset_all()

    {:ok, lens: lens}
  end

  describe "process_response/1" do
    test "handles successful response" do
      response = %{"ok" => true, "result" => %{"id" => 123, "name" => "Bot"}}
      assert {:ok, %{"id" => 123, "name" => "Bot"}} = Client.process_response(response)
    end

    test "handles error response" do
      response = %{"ok" => false, "description" => "Bad Request: chat not found"}
      assert {:error, "Bad Request: chat not found"} = Client.process_response(response)
    end

    test "handles unexpected response format" do
      response = %{"unexpected" => "format"}
      assert {:error, _} = Client.process_response(response)
    end
  end

  describe "rate limiting" do
    test "respects chat-specific rate limits" do
      chat_id = "123456"

      # Set up the rate limiter to be at the limit
      chat_config = %{name: :"telegram_chat_#{chat_id}", limit: 1, window_ms: 1000}
      table_name = Lux.Lenses.Telegram.RateLimiter.get_table_name(chat_config.name)

      # Ensure table exists
      :ets.new(table_name, [:named_table, :set, :public])

      # Insert an entry to trigger rate limiting
      now = System.monotonic_time(:millisecond)
      :ets.insert(table_name, {now, now})

      # Request should be delayed
      start_time = System.monotonic_time(:millisecond)
      RateLimiter.with_rate_limit(chat_id, fn -> :ok end)
      end_time = System.monotonic_time(:millisecond)

      # Should be delayed by at least 500ms
      assert end_time - start_time >= 500
    end

    test "respects global rate limits" do
      # Set up the global rate limiter to be at the limit
      global_config = %{name: :telegram_global, limit: 30, window_ms: 1000}
      table_name = Lux.Lenses.Telegram.RateLimiter.get_table_name(global_config.name)

      # Ensure table exists and is empty
      case :ets.info(table_name) do
        :undefined -> :ets.new(table_name, [:named_table, :set, :public])
        _ -> :ets.delete_all_objects(table_name)
      end

      # Insert 30 entries to trigger rate limiting
      now = System.monotonic_time(:millisecond)
      for i <- 1..30 do
        :ets.insert(table_name, {now - i, now - i})
      end

      # Request should be delayed
      chat_id = "another_chat"
      start_time = System.monotonic_time(:millisecond)
      RateLimiter.with_rate_limit(chat_id, fn -> :ok end)
      end_time = System.monotonic_time(:millisecond)

      # Should be delayed by at least 500ms
      assert end_time - start_time >= 500
    end
  end

  describe "body_or_params/2" do
    test "returns params for GET requests" do
      params = %{token: "123", chat_id: 456}
      assert [params: ^params] = Client.body_or_params(:get, params)
    end

    test "returns json for non-GET requests" do
      params = %{token: "123", chat_id: 456}
      assert [json: ^params] = Client.body_or_params(:post, params)
      assert [json: ^params] = Client.body_or_params(:delete, params)
    end
  end
end
