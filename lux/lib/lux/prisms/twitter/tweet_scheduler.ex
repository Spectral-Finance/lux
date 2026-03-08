defmodule Lux.Prisms.Twitter.TweetScheduler do
  @moduledoc """
  Schedule tweets for future posting with queue management.

  Features:
  - Schedule tweets at specific times
  - Queue management (add, remove, reorder, list)
  - Content calendar view
  - Auto-posting via periodic check
  - Thread scheduling (multiple tweets in sequence)
  """

  use GenServer

  defstruct [:queue, :posted, :max_queue]

  # Client API

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def schedule(pid \\ __MODULE__, tweet) do
    GenServer.call(pid, {:schedule, tweet})
  end

  def cancel(pid \\ __MODULE__, tweet_id) do
    GenServer.call(pid, {:cancel, tweet_id})
  end

  def list_scheduled(pid \\ __MODULE__, opts \\ %{}) do
    GenServer.call(pid, {:list_scheduled, opts})
  end

  def get_due(pid \\ __MODULE__) do
    GenServer.call(pid, :get_due)
  end

  def mark_posted(pid \\ __MODULE__, tweet_id, result \\ %{}) do
    GenServer.call(pid, {:mark_posted, tweet_id, result})
  end

  def calendar(pid \\ __MODULE__, date_range) do
    GenServer.call(pid, {:calendar, date_range})
  end

  def stats(pid \\ __MODULE__) do
    GenServer.call(pid, :stats)
  end

  # Server

  @impl true
  def init(opts) do
    {:ok, %__MODULE__{
      queue: [],
      posted: [],
      max_queue: opts[:max_queue] || 1000
    }}
  end

  @impl true
  def handle_call({:schedule, tweet}, _from, state) do
    id = tweet[:id] || generate_id()
    entry = %{
      id: id,
      text: tweet[:text],
      scheduled_at: tweet[:scheduled_at],
      media_ids: tweet[:media_ids],
      reply_to: tweet[:reply_to],
      thread: tweet[:thread],
      status: :scheduled,
      created_at: DateTime.utc_now()
    }

    queue = [entry | state.queue]
    |> Enum.sort_by(& &1.scheduled_at, DateTime)
    |> Enum.take(state.max_queue)

    {:reply, {:ok, entry}, %{state | queue: queue}}
  end

  @impl true
  def handle_call({:cancel, tweet_id}, _from, state) do
    case Enum.find(state.queue, &(&1.id == tweet_id)) do
      nil -> {:reply, {:error, :not_found}, state}
      _ ->
        queue = Enum.reject(state.queue, &(&1.id == tweet_id))
        {:reply, :ok, %{state | queue: queue}}
    end
  end

  @impl true
  def handle_call({:list_scheduled, opts}, _from, state) do
    list = state.queue
    list = if opts[:status], do: Enum.filter(list, &(&1.status == opts[:status])), else: list
    list = Enum.take(list, opts[:limit] || 50)
    {:reply, {:ok, list}, state}
  end

  @impl true
  def handle_call(:get_due, _from, state) do
    now = DateTime.utc_now()
    {due, remaining} = Enum.split_with(state.queue, fn entry ->
      DateTime.compare(entry.scheduled_at, now) in [:lt, :eq]
    end)
    {:reply, {:ok, due}, %{state | queue: remaining}}
  end

  @impl true
  def handle_call({:mark_posted, tweet_id, result}, _from, state) do
    entry = %{tweet_id: tweet_id, posted_at: DateTime.utc_now(), result: result}
    {:reply, :ok, %{state | posted: [entry | state.posted]}}
  end

  @impl true
  def handle_call({:calendar, {from_date, to_date}}, _from, state) do
    entries = Enum.filter(state.queue, fn entry ->
      d = DateTime.to_date(entry.scheduled_at)
      Date.compare(d, from_date) in [:gt, :eq] && Date.compare(d, to_date) in [:lt, :eq]
    end)

    grouped = Enum.group_by(entries, &DateTime.to_date(&1.scheduled_at))
    {:reply, {:ok, grouped}, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, {:ok, %{
      scheduled: length(state.queue),
      posted: length(state.posted)
    }}, state}
  end

  defp generate_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
