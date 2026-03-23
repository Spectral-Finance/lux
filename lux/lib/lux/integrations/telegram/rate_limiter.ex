defmodule Lux.Integrations.Telegram.RateLimiter do
  @moduledoc """
  GenServer-based rate limiter for Telegram Bot API requests.

  Enforces the Telegram Bot API rate limits:
  - Global limit: ~30 messages/second
  - Per-chat limit: ~1 message/second for private chats, ~3 messages/second for groups

  Uses ETS for high-performance rate tracking.

  ## Usage

      # Check if a request can be made (global)
      :ok = RateLimiter.check_rate()

      # Check if a request can be made to a specific chat
      :ok = RateLimiter.check_rate(chat_id)

      # Track a completed request (global)
      RateLimiter.track_request()

      # Track a completed request to a specific chat
      RateLimiter.track_request(chat_id)
  """

  use GenServer

  @global_limit 30
  @per_chat_limit 1
  @group_chat_limit 3
  @window_ms 1_000
  @cleanup_interval 5_000

  @table_name :telegram_rate_limiter
  @global_key :global

  # Client API

  @doc """
  Starts the rate limiter GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Checks if a global request can be made without exceeding rate limits.

  Returns `:ok` if the request is allowed, or `{:error, :rate_limited, retry_after_ms}`
  if the rate limit has been exceeded.
  """
  @spec check_rate() :: :ok | {:error, :rate_limited, non_neg_integer()}
  def check_rate do
    check_rate_for_key(@global_key, @global_limit)
  end

  @doc """
  Checks if a request to a specific chat can be made without exceeding rate limits.

  Also checks the global rate limit. Returns `:ok` if both limits allow the request,
  or `{:error, :rate_limited, retry_after_ms}` if either limit has been exceeded.

  The per-chat limit is 1 msg/sec for private chats and 3 msg/sec for group chats.
  Group chats are identified by negative chat IDs.
  """
  @spec check_rate(integer() | String.t()) :: :ok | {:error, :rate_limited, non_neg_integer()}
  def check_rate(chat_id) do
    with :ok <- check_rate() do
      limit = chat_limit(chat_id)
      check_rate_for_key({:chat, chat_id}, limit)
    end
  end

  @doc """
  Tracks a completed global request for rate limiting purposes.
  """
  @spec track_request() :: :ok
  def track_request do
    track_request_for_key(@global_key)
  end

  @doc """
  Tracks a completed request to a specific chat for rate limiting purposes.
  """
  @spec track_request(integer() | String.t()) :: :ok
  def track_request(chat_id) do
    track_request_for_key(@global_key)
    track_request_for_key({:chat, chat_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    Process.send_after(self(), :cleanup, @cleanup_interval)
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call(:cleanup, _from, state) do
    now = System.monotonic_time(:millisecond)
    cleanup_old_entries(now)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)
    cleanup_old_entries(now)
    Process.send_after(self(), :cleanup, @cleanup_interval)
    {:noreply, state}
  end

  # Private Functions

  defp check_rate_for_key(key, limit) do
    now = System.monotonic_time(:millisecond)
    window_start = now - @window_ms

    case :ets.lookup(@table_name, key) do
      [{^key, timestamps}] ->
        recent = Enum.filter(timestamps, fn ts -> ts > window_start end)

        if length(recent) >= limit do
          oldest = Enum.min(recent)
          retry_after = oldest + @window_ms - now
          {:error, :rate_limited, max(retry_after, 1)}
        else
          :ok
        end

      [] ->
        :ok
    end
  end

  defp track_request_for_key(key) do
    now = System.monotonic_time(:millisecond)
    window_start = now - @window_ms

    case :ets.lookup(@table_name, key) do
      [{^key, timestamps}] ->
        recent = Enum.filter(timestamps, fn ts -> ts > window_start end)
        :ets.insert(@table_name, {key, [now | recent]})

      [] ->
        :ets.insert(@table_name, {key, [now]})
    end

    :ok
  end

  defp chat_limit(chat_id) when is_integer(chat_id) and chat_id < 0, do: @group_chat_limit
  defp chat_limit(_chat_id), do: @per_chat_limit

  defp cleanup_old_entries(now) do
    window_start = now - @window_ms

    :ets.tab2list(@table_name)
    |> Enum.each(fn {key, timestamps} ->
      recent = Enum.filter(timestamps, fn ts -> ts > window_start end)

      if Enum.empty?(recent) do
        :ets.delete(@table_name, key)
      else
        :ets.insert(@table_name, {key, recent})
      end
    end)
  end
end
