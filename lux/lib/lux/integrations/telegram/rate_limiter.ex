defmodule Lux.Integrations.Telegram.RateLimiter do
  @moduledoc """
  Rate limiter for Telegram Bot API requests.

  Telegram enforces:
  - 30 messages per second to different chats
  - 1 message per second to the same chat
  - 20 messages per minute to the same group

  This GenServer tracks per-chat and global rate limits.
  """

  use GenServer

  @global_limit 30
  @chat_limit 1
  @group_minute_limit 20
  @window_ms 1000
  @group_window_ms 60_000

  # Client API

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Check if a request to `chat_id` is allowed. Returns :ok or {:wait, ms}."
  def check(pid \\ __MODULE__, chat_id) do
    GenServer.call(pid, {:check, chat_id})
  end

  @doc "Record a request to `chat_id`."
  def record(pid \\ __MODULE__, chat_id) do
    GenServer.cast(pid, {:record, chat_id})
  end

  @doc "Check and record atomically. Returns :ok or {:wait, ms}."
  def acquire(pid \\ __MODULE__, chat_id) do
    GenServer.call(pid, {:acquire, chat_id})
  end

  @doc "Get current rate limit status."
  def status(pid \\ __MODULE__) do
    GenServer.call(pid, :status)
  end

  # Server

  @impl true
  def init(_opts) do
    {:ok, %{
      global: [],
      chats: %{},
      group_chats: %{}
    }}
  end

  @impl true
  def handle_call({:check, chat_id}, _from, state) do
    now = System.monotonic_time(:millisecond)
    state = cleanup(state, now)

    cond do
      length(state.global) >= @global_limit ->
        oldest = hd(state.global)
        {:reply, {:wait, @window_ms - (now - oldest)}, state}

      chat_recent?(state, chat_id, now) ->
        {:reply, {:wait, @window_ms}, state}

      group_limited?(state, chat_id, now) ->
        {:reply, {:wait, @group_window_ms}, state}

      true ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:acquire, chat_id}, _from, state) do
    now = System.monotonic_time(:millisecond)
    state = cleanup(state, now)

    cond do
      length(state.global) >= @global_limit ->
        oldest = hd(state.global)
        {:reply, {:wait, @window_ms - (now - oldest)}, state}

      chat_recent?(state, chat_id, now) ->
        {:reply, {:wait, @window_ms}, state}

      group_limited?(state, chat_id, now) ->
        {:reply, {:wait, @group_window_ms}, state}

      true ->
        state = record_request(state, chat_id, now)
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    now = System.monotonic_time(:millisecond)
    state = cleanup(state, now)

    {:reply, %{
      global_used: length(state.global),
      global_limit: @global_limit,
      active_chats: map_size(state.chats)
    }, state}
  end

  @impl true
  def handle_cast({:record, chat_id}, state) do
    now = System.monotonic_time(:millisecond)
    state = record_request(state, chat_id, now)
    {:noreply, state}
  end

  defp record_request(state, chat_id, now) do
    %{state |
      global: state.global ++ [now],
      chats: Map.put(state.chats, chat_id, now),
      group_chats: Map.update(state.group_chats, chat_id, [now], &(&1 ++ [now]))
    }
  end

  defp chat_recent?(state, chat_id, now) do
    case Map.get(state.chats, chat_id) do
      nil -> false
      last -> now - last < @window_ms
    end
  end

  defp group_limited?(state, chat_id, now) do
    case Map.get(state.group_chats, chat_id) do
      nil -> false
      timestamps ->
        recent = Enum.filter(timestamps, &(now - &1 < @group_window_ms))
        length(recent) >= @group_minute_limit
    end
  end

  defp cleanup(state, now) do
    %{state |
      global: Enum.filter(state.global, &(now - &1 < @window_ms)),
      group_chats: state.group_chats
        |> Enum.map(fn {k, v} -> {k, Enum.filter(v, &(now - &1 < @group_window_ms))} end)
        |> Enum.reject(fn {_, v} -> v == [] end)
        |> Map.new()
    }
  end
end
