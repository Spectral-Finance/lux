defmodule Lux.Web3.EventMonitor.Store do
  @moduledoc """
  Persistent ETS store and replay engine for monitored smart contract events
  and subscription checkpoints.
  """

  alias Lux.Web3.EventMonitor.Decoder.DecodedEvent
  alias Lux.Web3.EventMonitor.Filter

  @events_table :lux_web3_monitored_events
  @checkpoints_table :lux_web3_event_checkpoints

  @doc """
  Initializes ETS tables for persisted events and block checkpoints.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    ensure_table(@events_table, :set)
    ensure_table(@checkpoints_table, :set)
    :ok
  end

  @doc """
  Clears all persisted events and checkpoints.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@events_table)
    :ets.delete_all_objects(@checkpoints_table)
    :ok
  end

  @doc """
  Persists a `%DecodedEvent{}` if not already stored, returning `{:new, event}`
  or `{:duplicate, event}`.
  """
  @spec save_event(DecodedEvent.t(), String.t() | nil) ::
          {:new, DecodedEvent.t()} | {:duplicate, DecodedEvent.t()}
  def save_event(%DecodedEvent{} = event, subscription_id \\ nil) do
    ensure_started()

    case :ets.lookup(@events_table, event.id) do
      [{_, existing, subs}] ->
        updated_subs =
          if is_binary(subscription_id) do
            Enum.uniq([subscription_id | subs])
          else
            subs
          end

        :ets.insert(@events_table, {event.id, existing, updated_subs})
        {:duplicate, existing}

      [] ->
        subs = if is_binary(subscription_id), do: [subscription_id], else: []
        :ets.insert(@events_table, {event.id, event, subs})
        {:new, event}
    end
  end

  @doc """
  Retrieves a persisted event by ID.
  """
  @spec get_event(String.t()) :: {:ok, DecodedEvent.t()} | {:error, :not_found}
  def get_event(event_id) when is_binary(event_id) do
    ensure_started()

    case :ets.lookup(@events_table, event_id) do
      [{^event_id, event, _subs}] -> {:ok, event}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Queries persisted events matching optional filter criteria and `:subscription_id`.
  """
  @spec list_events(map() | keyword()) :: [DecodedEvent.t()]
  def list_events(opts \\ %{}) do
    ensure_started()
    params = Map.new(opts)
    sub_id = Map.get(params, :subscription_id)
    limit = Map.get(params, :limit)
    filter = Filter.new(Map.drop(params, [:subscription_id, :limit]))

    events =
      @events_table
      |> :ets.tab2list()
      |> Enum.filter(fn {_id, event, subs} ->
        (is_nil(sub_id) or sub_id in subs) and Filter.matches?(event, filter)
      end)
      |> Enum.map(fn {_id, event, _subs} -> event end)
      |> Enum.sort_by(&{&1.block_number, &1.log_index}, :asc)

    if is_integer(limit) and limit >= 0 do
      Enum.take(events, limit)
    else
      events
    end
  end

  @doc """
  Replays persisted events matching `filter_opts` in chronological block/log order
  to a handler function (`(DecodedEvent.t() -> any())`) or target process PID.
  """
  @spec replay(map() | keyword(), (DecodedEvent.t() -> any()) | pid()) ::
          {:ok, [DecodedEvent.t()]}
  def replay(filter_opts, consumer) do
    events = list_events(filter_opts)

    Enum.each(events, fn event ->
      cond do
        is_function(consumer, 1) ->
          consumer.(event)

        is_pid(consumer) ->
          send(consumer, {:lux_event_replay, event})
      end
    end)

    {:ok, events}
  end

  @doc """
  Updates the last synced block number checkpoint for a subscription and chain.
  """
  @spec put_checkpoint(String.t(), atom(), non_neg_integer()) :: :ok
  def put_checkpoint(subscription_id, chain, block_number)
      when is_binary(subscription_id) and is_atom(chain) and is_integer(block_number) do
    ensure_started()
    :ets.insert(@checkpoints_table, {{subscription_id, chain}, block_number})
    :ok
  end

  @doc """
  Gets the last synced block number checkpoint for a subscription and chain.
  """
  @spec get_checkpoint(String.t(), atom()) :: non_neg_integer() | nil
  def get_checkpoint(subscription_id, chain) do
    ensure_started()

    case :ets.lookup(@checkpoints_table, {subscription_id, chain}) do
      [{_, block_number}] -> block_number
      [] -> nil
    end
  end

  defp ensure_table(name, kind) do
    case :ets.whereis(name) do
      :undefined ->
        try do
          :ets.new(name, [:named_table, :public, kind, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end
end
