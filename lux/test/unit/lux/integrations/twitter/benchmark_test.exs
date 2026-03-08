defmodule Lux.Integrations.Twitter.BenchmarkTest do
  @moduledoc """
  Performance benchmarks for Twitter API integration.
  Measures response parsing, rate limiter throughput, and OAuth signature generation.
  """
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.RateLimiter

  describe "OAuth signature generation" do
    test "generates signatures within 1ms" do
      params = %{
        "oauth_consumer_key" => "test_key",
        "oauth_nonce" => "testnonce123",
        "oauth_signature_method" => "HMAC-SHA1",
        "oauth_timestamp" => "1234567890",
        "oauth_token" => "test_token",
        "oauth_version" => "1.0"
      }

      {time_us, _} = :timer.tc(fn ->
        for _ <- 1..1000 do
          base_string = params
            |> Enum.sort()
            |> Enum.map(fn {k, v} -> "#{URI.encode_www_form(k)}=#{URI.encode_www_form(v)}" end)
            |> Enum.join("&")

          :crypto.mac(:hmac, :sha, "consumer_secret&token_secret", base_string)
          |> Base.encode64()
        end
      end)

      avg_us = time_us / 1000
      assert avg_us < 1000, "OAuth signature should take <1ms, got #{avg_us}μs"
    end
  end

  describe "Rate limiter throughput" do
    test "handles 10,000 check_rate calls in under 1 second" do
      {:ok, pid} = RateLimiter.start_link(name: nil)

      {time_us, _} = :timer.tc(fn ->
        for _ <- 1..10_000 do
          RateLimiter.check(pid, "/2/tweets/search/recent")
        end
      end)

      time_ms = time_us / 1000
      assert time_ms < 1000, "10k rate checks should take <1s, got #{time_ms}ms"
    end
  end

  describe "JSON response parsing" do
    test "parses tweet response within 0.5ms" do
      tweet_json = Jason.encode!(%{
        "data" => %{
          "id" => "1234567890",
          "text" => "Hello world " <> String.duplicate("x", 280),
          "author_id" => "9876543210",
          "created_at" => "2026-01-01T00:00:00.000Z",
          "public_metrics" => %{
            "retweet_count" => 100,
            "reply_count" => 50,
            "like_count" => 500,
            "quote_count" => 25
          }
        },
        "includes" => %{
          "users" => [%{"id" => "9876543210", "name" => "Test", "username" => "test"}]
        }
      })

      {time_us, _} = :timer.tc(fn ->
        for _ <- 1..1000 do
          Jason.decode!(tweet_json)
        end
      end)

      avg_us = time_us / 1000
      assert avg_us < 500, "Tweet parsing should take <0.5ms, got #{avg_us}μs"
    end

    test "parses timeline (100 tweets) within 5ms" do
      tweets = for i <- 1..100 do
        %{"id" => "#{i}", "text" => "Tweet #{i}", "author_id" => "author_#{i}"}
      end
      timeline_json = Jason.encode!(%{"data" => tweets, "meta" => %{"result_count" => 100}})

      {time_us, _} = :timer.tc(fn ->
        for _ <- 1..100 do
          Jason.decode!(timeline_json)
        end
      end)

      avg_us = time_us / 100
      assert avg_us < 5000, "Timeline parsing should take <5ms, got #{avg_us}μs"
    end
  end
end
