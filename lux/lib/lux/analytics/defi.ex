defmodule Lux.Analytics.DeFi do
  @moduledoc """
  DeFi analytics integration for TVL tracking, protocol metrics,
  yield analytics, and volume analysis using DeFiLlama and Dune Analytics.
  """

  alias Lux.Analytics.DeFi.{DefiLlama, Dune, Protocol, TVL, Yield, Volume}

  # TVL Tracking

  @doc """
  Get TVL for all protocols or a specific protocol.
  """
  def get_tvl(protocol \\ nil) do
    TVL.get_tvl(protocol)
  end

  @doc """
  Get historical TVL data for a protocol.
  """
  def get_historical_tvl(protocol, opts \\ []) do
    TVL.get_historical_tvl(protocol, opts)
  end

  @doc """
  Get TVL for a specific chain.
  """
  def get_chain_tvl(chain) do
    TVL.get_chain_tvl(chain)
  end

  # Protocol Metrics

  @doc """
  Get comprehensive metrics for a protocol.
  """
  def get_protocol_metrics(protocol) do
    Protocol.get_metrics(protocol)
  end

  @doc """
  List all available protocols.
  """
  def list_protocols(opts \\ []) do
    Protocol.list_protocols(opts)
  end

  @doc """
  Get protocol metadata.
  """
  def get_protocol_info(protocol) do
    Protocol.get_info(protocol)
  end

  # Yield Analytics

  @doc """
  Get yield data for pools.
  """
  def get_yields(opts \\ []) do
    Yield.get_yields(opts)
  end

  @doc """
  Get yield for a specific pool.
  """
  def get_pool_yield(pool_id) do
    Yield.get_pool_yield(pool_id)
  end

  @doc """
  Get yield history for a pool.
  """
  def get_yield_history(pool_id, opts \\ []) do
    Yield.get_yield_history(pool_id, opts)
  end

  # Volume Analysis

  @doc """
  Get volume data for protocols.
  """
  def get_volumes(opts \\ []) do
    Volume.get_volumes(opts)
  end

  @doc """
  Get volume for a specific protocol.
  """
  def get_protocol_volume(protocol, opts \\ []) do
    Volume.get_protocol_volume(protocol, opts)
  end

  @doc """
  Get historical volume data.
  """
  def get_volume_history(protocol, opts \\ []) do
    Volume.get_volume_history(protocol, opts)
  end

  # Custom Query Support

  @doc """
  Execute a custom Dune Analytics query.
  """
  def execute_query(query_id, params \\ %{}) do
    Dune.execute_query(query_id, params)
  end

  @doc """
  Get results from a Dune Analytics query.
  """
  def get_query_results(query_id) do
    Dune.get_query_results(query_id)
  end

  @doc """
  Run a custom Dune Analytics query and wait for results.
  """
  def run_query(query_sql, params \\ %{}) do
    Dune.run_query(query_sql, params)
  end

  # Alert System

  @doc """
  Set up an alert for TVL changes.
  """
  def set_tvl_alert(protocol, threshold, callback) do
    Lux.Analytics.DeFi.Alert.set_tvl_alert(protocol, threshold, callback)
  end

  @doc """
  Set up an alert for yield changes.
  """
  def set_yield_alert(pool_id, threshold, callback) do
    Lux.Analytics.DeFi.Alert.set_yield_alert(pool_id, threshold, callback)
  end

  @doc """
  Set up an alert for volume changes.
  """
  def set_volume_alert(protocol, threshold, callback) do
    Lux.Analytics.DeFi.Alert.set_volume_alert(protocol, threshold, callback)
  end
end