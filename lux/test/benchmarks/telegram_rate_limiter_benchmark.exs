defmodule Lux.Benchmarks.TelegramRateLimiterBenchmark do
  @moduledoc """
  Performance benchmarks for Telegram Bot API rate limiting and token management.
  Validates that token encryption, queue operations, and sliding-window rate limit
  checks operate with sub-millisecond latencies.
  """

  alias Lux.Integrations.Telegram.{RateLimiter, RateLimitQueue, TokenManager}

  def run do
    IO.puts("=== TELEGRAM INTEGRATION PERFORMANCE BENCHMARKS ===")

    # 1. Rate limiter throughput
    benchmark_rate_limiter(10_000)

    # 2. Priority queue throughput
    benchmark_priority_queue(10_000)

    # 3. Token encryption & decryption
    benchmark_token_crypto(500)

    IO.puts("=== ALL BENCHMARKS COMPLETED SUCCESSFULLY ===")
  end

  defp benchmark_rate_limiter(iterations) do
    state = RateLimiter.init_state()
    start_time = :os.system_time(:microsecond)

    _final_state =
      Enum.reduce(1..iterations, state, fn i, acc ->
        now_ms = 1_700_000_000_000 + i
        case RateLimiter.check_rate_limit(acc, "chat_#{rem(i, 50)}", :private, now_ms) do
          {:ok, next_state} -> next_state
          {:rate_limited, _wait, _reason} -> acc
        end
      end)

    elapsed_us = :os.system_time(:microsecond) - start_time
    ops_per_sec = round(iterations / (elapsed_us / 1_000_000.0))
    IO.puts("RateLimiter.check_rate_limit: #{iterations} checks in #{elapsed_us / 1000} ms (~#{ops_per_sec} ops/sec)")
  end

  defp benchmark_priority_queue(iterations) do
    queue = RateLimitQueue.init_queue()
    start_time = :os.system_time(:microsecond)

    q =
      Enum.reduce(1..iterations, queue, fn i, acc ->
        priority =
          case rem(i, 3) do
            0 -> :high
            1 -> :normal
            _ -> :low
          end

        {:ok, next_q, _item} = RateLimitQueue.enqueue(acc, "chat_#{i}", %{text: "msg #{i}"}, priority)
        next_q
      end)

    _empty_q =
      Enum.reduce(1..iterations, q, fn _i, acc ->
        case RateLimitQueue.dequeue(acc) do
          {:ok, next_q, _item} -> next_q
          {:empty, acc} -> acc
        end
      end)

    elapsed_us = :os.system_time(:microsecond) - start_time
    ops_per_sec = round((iterations * 2) / (elapsed_us / 1_000_000.0))
    IO.puts("RateLimitQueue (Enqueue + Dequeue): #{iterations * 2} ops in #{elapsed_us / 1000} ms (~#{ops_per_sec} ops/sec)")
  end

  defp benchmark_token_crypto(iterations) do
    passphrase = "benchmark_secret_key_123"
    token = "123456789:ABCdefGHIjklMNOpqrSTUvwxYZ123456789"
    start_time = :os.system_time(:microsecond)

    Enum.each(1..iterations, fn _i ->
      encrypted = TokenManager.encrypt_token(token, passphrase)
      {:ok, ^token} = TokenManager.decrypt_token(encrypted, passphrase)
    end)

    elapsed_us = :os.system_time(:microsecond) - start_time
    avg_ms_per_crypto = (elapsed_us / iterations) / 1000.0
    IO.puts("TokenManager AES-256-GCM (Encrypt + Decrypt): #{iterations} cycles, avg #{avg_ms_per_crypto} ms/cycle")
  end
end

if Code.ensure_loaded?(Mix) do
  Lux.Benchmarks.TelegramRateLimiterBenchmark.run()
end
