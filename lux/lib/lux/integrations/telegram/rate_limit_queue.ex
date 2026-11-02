defmodule Lux.Integrations.Telegram.RateLimitQueue do
  @moduledoc """
  Priority-based message queuing system for Telegram Bot API.
  Supports `:high`, `:normal`, and `:low` priorities, enabling smooth
  message delivery that automatically honors Telegram's rate limits.
  """

  @type priority :: :high | :normal | :low

  @type queued_item :: %{
          id: String.t(),
          chat_id: String.t() | integer(),
          payload: map(),
          priority: priority(),
          enqueued_at: integer()
        }

  @type queue_state :: %{
          high: list(queued_item()),
          normal: list(queued_item()),
          low: list(queued_item())
        }

  @doc """
  Initializes an empty priority queue.
  """
  @spec init_queue() :: queue_state()
  def init_queue do
    %{
      high: [],
      normal: [],
      low: []
    }
  end

  @doc """
  Enqueues a message payload with specified priority (defaults to `:normal`).
  """
  @spec enqueue(queue_state(), String.t() | integer(), map(), priority()) ::
          {:ok, queue_state(), queued_item()}
  def enqueue(queue, chat_id, payload, priority \\ :normal) do
    item = %{
      id: "msg_#{:os.system_time(:microsecond)}",
      chat_id: chat_id,
      payload: payload,
      priority: priority,
      enqueued_at: :os.system_time(:millisecond)
    }

    updated_queue =
      case priority do
        :high -> %{queue | high: queue.high ++ [item]}
        :low -> %{queue | low: queue.low ++ [item]}
        _ -> %{queue | normal: queue.normal ++ [item]}
      end

    {:ok, updated_queue, item}
  end

  @doc """
  Pops the next highest priority message from the queue.
  Order of precedence: `:high` -> `:normal` -> `:low`.
  """
  @spec dequeue(queue_state()) :: {:ok, queue_state(), queued_item()} | {:empty, queue_state()}
  def dequeue(%{high: [item | rest]} = queue) do
    {:ok, %{queue | high: rest}, item}
  end

  def dequeue(%{normal: [item | rest]} = queue) do
    {:ok, %{queue | normal: rest}, item}
  end

  def dequeue(%{low: [item | rest]} = queue) do
    {:ok, %{queue | low: rest}, item}
  end

  def dequeue(queue) do
    {:empty, queue}
  end

  @doc """
  Returns the total count of pending messages across all priority bands.
  """
  @spec total_count(queue_state()) :: non_neg_integer()
  def total_count(queue) do
    length(queue.high) + length(queue.normal) + length(queue.low)
  end
end
