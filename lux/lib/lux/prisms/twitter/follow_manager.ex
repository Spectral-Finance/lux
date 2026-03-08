defmodule Lux.Prisms.Twitter.FollowManager do
  @moduledoc """
  Manages follow/unfollow automation with rate limiting and tracking.
  """

  use GenServer

  defstruct [:following, :unfollowed, :pending, :daily_limit, :daily_count, :last_reset]

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def queue_follow(pid \\ __MODULE__, user_id, reason \\ :rule) do
    GenServer.call(pid, {:queue_follow, user_id, reason})
  end

  def queue_unfollow(pid \\ __MODULE__, user_id, reason \\ :rule) do
    GenServer.call(pid, {:queue_unfollow, user_id, reason})
  end

  def get_pending(pid \\ __MODULE__) do
    GenServer.call(pid, :get_pending)
  end

  def mark_done(pid \\ __MODULE__, user_id, action) do
    GenServer.call(pid, {:mark_done, user_id, action})
  end

  def stats(pid \\ __MODULE__) do
    GenServer.call(pid, :stats)
  end

  @impl true
  def init(opts) do
    {:ok, %__MODULE__{
      following: MapSet.new(),
      unfollowed: [],
      pending: [],
      daily_limit: opts[:daily_limit] || 50,
      daily_count: 0,
      last_reset: Date.utc_today()
    }}
  end

  @impl true
  def handle_call({:queue_follow, user_id, reason}, _from, state) do
    state = maybe_reset_daily(state)
    if state.daily_count >= state.daily_limit do
      {:reply, {:error, :daily_limit_reached}, state}
    else
      entry = %{user_id: user_id, action: :follow, reason: reason, queued_at: DateTime.utc_now()}
      {:reply, {:ok, entry}, %{state | pending: state.pending ++ [entry]}}
    end
  end

  @impl true
  def handle_call({:queue_unfollow, user_id, reason}, _from, state) do
    entry = %{user_id: user_id, action: :unfollow, reason: reason, queued_at: DateTime.utc_now()}
    {:reply, {:ok, entry}, %{state | pending: state.pending ++ [entry]}}
  end

  @impl true
  def handle_call(:get_pending, _from, state) do
    {:reply, {:ok, state.pending}, state}
  end

  @impl true
  def handle_call({:mark_done, user_id, :follow}, _from, state) do
    state = maybe_reset_daily(state)
    pending = Enum.reject(state.pending, &(&1.user_id == user_id && &1.action == :follow))
    {:reply, :ok, %{state |
      following: MapSet.put(state.following, user_id),
      pending: pending,
      daily_count: state.daily_count + 1
    }}
  end

  @impl true
  def handle_call({:mark_done, user_id, :unfollow}, _from, state) do
    pending = Enum.reject(state.pending, &(&1.user_id == user_id && &1.action == :unfollow))
    {:reply, :ok, %{state |
      following: MapSet.delete(state.following, user_id),
      unfollowed: [%{user_id: user_id, at: DateTime.utc_now()} | state.unfollowed],
      pending: pending
    }}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, {:ok, %{
      following: MapSet.size(state.following),
      unfollowed_total: length(state.unfollowed),
      pending: length(state.pending),
      daily_count: state.daily_count,
      daily_limit: state.daily_limit
    }}, state}
  end

  defp maybe_reset_daily(state) do
    today = Date.utc_today()
    if Date.compare(today, state.last_reset) == :gt do
      %{state | daily_count: 0, last_reset: today}
    else
      state
    end
  end
end
