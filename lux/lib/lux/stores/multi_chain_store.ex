defmodule Lux.Stores.MultiChainStore do
  use GenServer

  @default_opts [retention_days: 7]
  @table_name :multi_chain_store

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    retention_days = Keyword.get(opts, :retention_days, @default_opts[:retention_days])
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{retention_days: retention_days}}
  end

  def insert(key, value) do
    :ets.insert(@table_name, {key, value, DateTime.utc_now()})
  end

  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, _timestamp}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end
end
