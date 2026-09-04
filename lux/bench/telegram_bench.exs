# bench/telegram_bench.exs
#
# Run with:
#   mix run bench/telegram_bench.exs

defmodule Lux.TelegramBench do
  @moduledoc """
  Benchmark suite measuring throughput and latency of Telegram integration components:
  - Signal creation and schema validation (TelegramUpdate.new/1)
  - Helper extraction (chat_id, text, update_id, to_struct)
  - Atom-safe key conversion (to_atom_keys/1)
  - Webhook Plug pipeline throughput (valid request, 400 Bad Request rejection, 401 Unauthorized)
  - Poller batch update ingestion
  """

  alias Lux.Signals.TelegramUpdate
  alias Lux.Telegram.WebhookPlug
  alias Lux.Telegram.Poller

  @iterations 10_000

  @sample_message_payload %{
    "update_id" => 100_001,
    "message" => %{
      "message_id" => 42,
      "date" => 1_700_000_000,
      "chat" => %{"id" => 987_654_321, "type" => "private", "username" => "lux_user"},
      "from" => %{"id" => 987_654_321, "is_bot" => false, "first_name" => "Lux", "username" => "lux_user"},
      "text" => "Hello, Lux Agent! Please execute workflow #123."
    }
  }

  @sample_callback_payload %{
    "update_id" => 100_002,
    "callback_query" => %{
      "id" => "cb_999",
      "chat_instance" => "inst_123",
      "data" => "action:approve:123",
      "from" => %{"id" => 987_654_321, "is_bot" => false, "first_name" => "Lux"},
      "message" => %{
        "message_id" => 43,
        "chat" => %{"id" => 987_654_321, "type" => "private"}
      }
    }
  }

  @sample_invalid_payload %{"missing_update_id" => true, "invalid" => "data"}

  def run do
    IO.puts("\n=================================================================")
    IO.puts("          Lux Telegram Core Integration Benchmark Suite           ")
    IO.puts("=================================================================\n")
    IO.puts("Iterations per benchmark: #{@iterations}\n")

    {:ok, valid_signal} = TelegramUpdate.new(@sample_message_payload)
    webhook_opts = WebhookPlug.init(secret_token: "bench_secret", handler: fn _sig -> :ok end)
    valid_json_body = Jason.encode!(@sample_message_payload)

    poller_plug = fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "ok" => true,
        "result" => [
          %{"update_id" => 1, "message" => %{"chat" => %{"id" => 101}, "text" => "m1"}},
          %{"update_id" => 2, "message" => %{"chat" => %{"id" => 102}, "text" => "m2"}},
          %{"update_id" => 3, "message" => %{"chat" => %{"id" => 103}, "text" => "m3"}}
        ]
      }))
    end

    {:ok, poller_pid} =
      Poller.start_link(%{
        token: "bench_token",
        plug: poller_plug,
        handler: fn _sig -> :ok end,
        autostart: false
      })

    benchmarks = [
      {"TelegramUpdate.new/1 (Message update)", fn ->
        {:ok, _} = TelegramUpdate.new(@sample_message_payload)
      end},

      {"TelegramUpdate.new/1 (Callback query)", fn ->
        {:ok, _} = TelegramUpdate.new(@sample_callback_payload)
      end},

      {"TelegramUpdate.new/1 (Invalid payload rejection)", fn ->
        {:error, _} = TelegramUpdate.new(@sample_invalid_payload)
      end},

      {"TelegramUpdate.chat_id/1 extraction", fn ->
        _ = TelegramUpdate.chat_id(valid_signal)
      end},

      {"TelegramUpdate.text/1 extraction", fn ->
        _ = TelegramUpdate.text(valid_signal)
      end},

      {"TelegramUpdate.to_struct/1 conversion", fn ->
        _ = TelegramUpdate.to_struct(valid_signal)
      end},

      {"TelegramUpdate.to_atom_keys/1 (Atom-safe)", fn ->
        _ = TelegramUpdate.to_atom_keys(@sample_message_payload)
      end},

      {"WebhookPlug.call/2 (Valid signed request -> 200)", fn ->
        _ =
          :post
          |> Plug.Test.conn("/webhook", valid_json_body)
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> Plug.Conn.put_req_header("x-telegram-bot-api-secret-token", "bench_secret")
          |> WebhookPlug.call(webhook_opts)
      end},

      {"WebhookPlug.call/2 (Malformed JSON rejection -> 400)", fn ->
        _ =
          :post
          |> Plug.Test.conn("/webhook", "{invalid-json-payload")
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> Plug.Conn.put_req_header("x-telegram-bot-api-secret-token", "bench_secret")
          |> WebhookPlug.call(webhook_opts)
      end},

      {"WebhookPlug.call/2 (Unauthorized rejection -> 401)", fn ->
        _ =
          :post
          |> Plug.Test.conn("/webhook", valid_json_body)
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> Plug.Conn.put_req_header("x-telegram-bot-api-secret-token", "wrong_secret")
          |> WebhookPlug.call(webhook_opts)
      end},

      {"Poller.poll_once/1 (Batch of 3 updates)", fn ->
        {:ok, _} = Poller.poll_once(poller_pid)
      end}
    ]

    results =
      Enum.map(benchmarks, fn {name, func} ->
        # Warmup
        for _ <- 1..100, do: func.()

        # Timed run
        latencies =
          for _ <- 1..@iterations do
            t0 = System.monotonic_time(:microsecond)
            func.()
            t1 = System.monotonic_time(:microsecond)
            max(t1 - t0, 0)
          end

        total_us = Enum.sum(latencies)
        mean_us = total_us / @iterations
        sorted = Enum.sort(latencies)
        min_us = hd(sorted)
        max_us = List.last(sorted)
        p99_index = trunc(@iterations * 0.99) - 1
        p99_us = Enum.at(sorted, max(p99_index, 0))
        ips = if total_us > 0, do: trunc(@iterations / (total_us / 1_000_000)), else: 0

        %{
          name: name,
          total_ms: Float.round(total_us / 1_000, 2),
          mean_us: Float.round(mean_us, 2),
          min_us: min_us,
          max_us: max_us,
          p99_us: p99_us,
          ips: ips
        }
      end)

    print_results(results)
    write_markdown_report(results)
  end

  defp print_results(results) do
    IO.puts(String.pad_trailing("Benchmark", 55) <>
            String.pad_leading("IPS", 12) <>
            String.pad_leading("Mean (µs)", 12) <>
            String.pad_leading("Min (µs)", 10) <>
            String.pad_leading("p99 (µs)", 10) <>
            String.pad_leading("Total (ms)", 12))
    IO.puts(String.duplicate("-", 111))

    Enum.each(results, fn r ->
      IO.puts(
        String.pad_trailing(r.name, 55) <>
        String.pad_leading(format_number(r.ips), 12) <>
        String.pad_leading(:erlang.float_to_binary(r.mean_us, decimals: 2), 12) <>
        String.pad_leading("#{r.min_us}", 10) <>
        String.pad_leading("#{r.p99_us}", 10) <>
        String.pad_leading(:erlang.float_to_binary(r.total_ms, decimals: 2), 12)
      )
    end)
    IO.puts(String.duplicate("=", 111) <> "\n")
  end

  defp write_markdown_report(results) do
    File.mkdir_p!("bench/results")
    report_path = "bench/results/telegram_bench.md"

    rows =
      Enum.map_join(results, "\n", fn r ->
        "| #{r.name} | #{format_number(r.ips)} | #{r.mean_us} µs | #{r.min_us} µs | #{r.p99_us} µs | #{r.total_ms} ms |"
      end)

    content = """
    # Telegram Integration Benchmark Results

    - **Iterations**: #{@iterations} per benchmark
    - **Date**: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    - **Host**: Linux / BEAM (Elixir #{System.version()})

    | Benchmark | Operations / sec (IPS) | Mean Latency | Min Latency | p99 Latency | Total Time |
    |:---|:---:|:---:|:---:|:---:|:---:|
    #{rows}
    """

    File.write!(report_path, content)
    IO.puts("Saved benchmark report to: #{report_path}")
  end

  defp format_number(n) do
    n
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
end

Lux.TelegramBench.run()
