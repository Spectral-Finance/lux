defmodule Lux.Integrations.Telegram.Queue do
  @moduledoc """
  A rate-limiting queue for outgoing Telegram Bot API requests.
  Ensures that we respect Telegram's rate limits and gracefully handle 429 Too Many Requests
  by parsing `retry_after` and delaying subsequent requests.
  """
  use GenServer
  require Logger

  @default_interval 35 # roughly 30 requests per second is Telegram's general limit, 1000/30 = 33.3ms
  @max_retries 3

  # --- Client API ---

  @doc """
  Starts the queue.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Enqueues a request to be executed.
  The request is an anonymous function that returns `{:ok, response}` or `{:error, reason}`.
  This is a synchronous call that will block until the request is executed and returns.
  """
  def enqueue(server \\ __MODULE__, request_fun) do
    GenServer.call(server, {:enqueue, request_fun}, :infinity)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    state = %{
      queue: :queue.new(),
      processing: false,
      interval: Keyword.get(opts, :interval, @default_interval),
      retry_after_ms: 0
    }
    {:ok, state}
  end

  @impl true
  def handle_call({:enqueue, request_fun}, from, state) do
    # Add to queue with 0 retries
    item = %{request_fun: request_fun, from: from, retries: 0}
    new_queue = :queue.in(item, state.queue)
    new_state = %{state | queue: new_queue}
    
    # If not currently processing, trigger the loop
    if not state.processing do
      send(self(), :process_next)
      {:noreply, %{new_state | processing: true}}
    else
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:process_next, state) do
    if state.retry_after_ms > 0 do
      # We hit a rate limit previously, wait before processing the next item
      Process.send_after(self(), :process_next, state.retry_after_ms)
      {:noreply, %{state | retry_after_ms: 0}}
    else
      case :queue.out(state.queue) do
        {{:value, item}, new_queue} ->
          state = %{state | queue: new_queue}
          process_item(item, state)

        {:empty, _queue} ->
          {:noreply, %{state | processing: false}}
      end
    end
  end

  defp process_item(%{request_fun: request_fun, from: from, retries: retries} = item, state) do
    case request_fun.() do
      {:error, {:rate_limited, retry_after_sec}} ->
        if retries < @max_retries do
          retry_ms =
            case retry_after_sec do
              val when is_integer(val) and val >= 0 -> val * 1000
              val when is_binary(val) ->
                case Regex.run(~r/retry after (\d+)/i, val) do
                  [_, num] -> String.to_integer(num) * 1000
                  nil -> 30_000
                end
              _ -> 30_000
            end

          # Clamp delay between 1 second and 60 seconds to prevent global queue stalls
          retry_ms = min(max(retry_ms, 1000), 60_000)

          Logger.warning("Telegram API Rate Limited. Retrying after #{retry_ms} ms.")
          
          # Put item back at the front of the queue
          new_item = %{item | retries: retries + 1}
          new_queue = :queue.in_r(new_item, state.queue)
          
          # Schedule next processing after the delay
          Process.send_after(self(), :process_next, retry_ms)
          {:noreply, %{state | queue: new_queue, retry_after_ms: 0}}
        else
          Logger.error("Telegram API Rate Limited. Max retries exceeded.")
          GenServer.reply(from, {:error, :rate_limit_exceeded})
          # Continue with next items
          Process.send_after(self(), :process_next, state.interval)
          {:noreply, state}
        end

      result ->
        GenServer.reply(from, result)
        Process.send_after(self(), :process_next, state.interval)
        {:noreply, state}
    end
  end
end
