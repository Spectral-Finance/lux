# Run this benchmark from the lux root directory using:
#   mix run benchmarks/telegram_queue_bench.exs
#
# Note: This benchmark requires the Lux application to be started.

Lux.Integrations.Telegram.Queue.start_link([])

Benchee.run(
  %{
    "queue_serialization" => fn ->
      Lux.Integrations.Telegram.Queue.enqueue(fn ->
        {:ok, %{"ok" => true}}
      end)
    end
  },
  time: 3,
  memory_time: 1
)
