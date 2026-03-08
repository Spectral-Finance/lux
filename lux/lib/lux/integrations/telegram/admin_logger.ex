defmodule Lux.Integrations.Telegram.AdminLogger do
  @moduledoc """
  Logs and tracks admin actions in Telegram groups for audit and moderation history.

  Uses ETS for fast in-memory access with optional disk persistence.
  """

  use GenServer

  defstruct [:table, :max_entries, :persist_path]

  # Client API

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def log_action(pid \\ __MODULE__, entry) do
    GenServer.call(pid, {:log, entry})
  end

  def query(pid \\ __MODULE__, filters \\ %{}) do
    GenServer.call(pid, {:query, filters})
  end

  def count(pid \\ __MODULE__) do
    GenServer.call(pid, :count)
  end

  def recent(pid \\ __MODULE__, n \\ 20) do
    GenServer.call(pid, {:recent, n})
  end

  def clear(pid \\ __MODULE__) do
    GenServer.call(pid, :clear)
  end

  # Server

  @impl true
  def init(opts) do
    table = :ets.new(:admin_log, [:ordered_set, :private])
    state = %__MODULE__{
      table: table,
      max_entries: opts[:max_entries] || 10_000,
      persist_path: opts[:persist_path]
    }

    if state.persist_path && File.exists?(state.persist_path) do
      case File.read(state.persist_path) do
        {:ok, bin} -> Enum.each(:erlang.binary_to_term(bin), &:ets.insert(table, &1))
        _ -> :ok
      end
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:log, entry}, _from, state) do
    ts = System.system_time(:microsecond)
    full_entry = Map.merge(entry, %{
      id: ts,
      logged_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
    :ets.insert(state.table, {ts, full_entry})
    maybe_evict(state)
    maybe_persist(state)
    {:reply, {:ok, ts}, state}
  end

  @impl true
  def handle_call({:query, filters}, _from, state) do
    entries = :ets.tab2list(state.table)
      |> Enum.map(fn {_, e} -> e end)
      |> Enum.reverse()
      |> filter_entries(filters)
      |> Enum.take(filters[:limit] || 100)
    {:reply, {:ok, entries}, state}
  end

  @impl true
  def handle_call(:count, _from, state) do
    {:reply, :ets.info(state.table, :size), state}
  end

  @impl true
  def handle_call({:recent, n}, _from, state) do
    entries = :ets.tab2list(state.table)
      |> Enum.map(fn {_, e} -> e end)
      |> Enum.reverse()
      |> Enum.take(n)
    {:reply, {:ok, entries}, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.table)
    {:reply, :ok, state}
  end

  defp filter_entries(entries, filters) do
    entries
    |> maybe_filter(:action, filters[:action])
    |> maybe_filter(:chat_id, filters[:chat_id])
    |> maybe_filter(:admin_id, filters[:admin_id])
    |> maybe_filter(:target_user_id, filters[:target_user_id])
  end

  defp maybe_filter(entries, _field, nil), do: entries
  defp maybe_filter(entries, field, value) do
    Enum.filter(entries, &(Map.get(&1, field) == value))
  end

  defp maybe_evict(state) do
    size = :ets.info(state.table, :size)
    if size > state.max_entries do
      :ets.tab2list(state.table) |> Enum.take(div(state.max_entries, 10)) |> Enum.each(fn {k, _} -> :ets.delete(state.table, k) end)
    end
  end

  defp maybe_persist(%{persist_path: nil}), do: :ok
  defp maybe_persist(state) do
    data = :ets.tab2list(state.table)
    File.write(state.persist_path, :erlang.term_to_binary(data))
  end
end
