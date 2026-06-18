defmodule TelegramBenchmark do
  @moduledoc """
  Benchmark script for measuring the performance of request auth replacement
  and update parsing/normalization.
  """

  def run do
    IO.puts("=== Running Telegram Integration Benchmarks ===")
    IO.puts("Env: #{Mix.env()}")
    IO.puts("")

    # Benchmark 1: Auth Replacement (add_auth/1)
    lens = %Lux.Lens{url: "https://api.telegram.org/bot:token/getUpdates"}

    # Warmup
    for _ <- 1..1000, do: Lux.Integrations.Telegram.add_auth(lens)

    iterations = 50_000
    {time_us, _} = :timer.tc(fn ->
      for _ <- 1..iterations, do: Lux.Integrations.Telegram.add_auth(lens)
    end)

    ops_sec = (iterations / (time_us / 1_000_000)) |> round()
    avg_us = (time_us / iterations) |> Float.round(3)
    IO.puts("add_auth/1 (Auth replacement on Lens):")
    IO.puts("  Iterations: #{iterations}")
    IO.puts("  Total Time: #{time_us / 1000} ms")
    IO.puts("  Avg Time:   #{avg_us} \u00b5s")
    IO.puts("  Throughput: #{ops_sec} ops/sec")
    IO.puts("")

    # Benchmark 2: Update Parsing (Update.parse/1)
    raw_update = %{
      "update_id" => 10000,
      "message" => %{
        "message_id" => 1,
        "chat" => %{"id" => 123456},
        "from" => %{"id" => 98765},
        "text" => "Hello World"
      }
    }

    # Warmup
    for _ <- 1..1000, do: Lux.Integrations.Telegram.Update.parse(raw_update)

    {time_us_parse, _} = :timer.tc(fn ->
      for _ <- 1..iterations, do: Lux.Integrations.Telegram.Update.parse(raw_update)
    end)

    ops_sec_parse = (iterations / (time_us_parse / 1_000_000)) |> round()
    avg_us_parse = (time_us_parse / iterations) |> Float.round(3)
    IO.puts("Update.parse/1 (Update normalizer):")
    IO.puts("  Iterations: #{iterations}")
    IO.puts("  Total Time: #{time_us_parse / 1000} ms")
    IO.puts("  Avg Time:   #{avg_us_parse} \u00b5s")
    IO.puts("  Throughput: #{ops_sec_parse} ops/sec")
  end
end

TelegramBenchmark.run()
