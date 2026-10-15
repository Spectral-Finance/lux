defmodule Lux.Web3.Auth.AuditLog do
  @moduledoc """
  Structured security audit logger for Web3 authentication and authorization events.
  """

  @table :lux_web3_auth_audit_logs

  @doc """
  Initializes the ETS audit log table.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :public, :ordered_set, read_concurrency: true])
          :ok
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end

  @doc """
  Clears all recorded audit events.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc """
  Appends an audit event entry.
  """
  @spec record(atom(), String.t() | nil, map()) :: map()
  def record(event_type, address, metadata \\ %{}) when is_atom(event_type) do
    ensure_started()
    seq = System.unique_integer([:positive, :monotonic])

    entry = %{
      id: seq,
      event_type: event_type,
      address: if(is_binary(address), do: String.downcase(address), else: nil),
      metadata: metadata,
      timestamp: DateTime.utc_now()
    }

    :ets.insert(@table, {seq, entry})
    entry
  end

  @doc """
  Lists recorded audit log entries, optionally filtered by `:address` or `:event_type`.
  """
  @spec list_entries(keyword()) :: [map()]
  def list_entries(opts \\ []) do
    ensure_started()
    addr_filter = Keyword.get(opts, :address)
    type_filter = Keyword.get(opts, :event_type)

    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_seq, entry} -> entry end)
    |> Enum.filter(fn entry ->
      addr_ok =
        is_nil(addr_filter) or entry.address == String.downcase(to_string(addr_filter))

      type_ok = is_nil(type_filter) or entry.event_type == type_filter
      addr_ok and type_ok
    end)
  end
end
