```diff
--- /dev/null
+++ b/lux/lib/lux/integrations/defi_analytics.ex
@@ -0,0 +1,212 @@
+defmodule Lux.Integrations.DefiAnalytics do
+  @moduledoc """
+  DeFi analytics integration with DeFiLlama and Dune Analytics.
+  Provides TVL tracking, protocol metrics, yield analytics, volume analysis,
+  custom query support, historical data access, and alert system.
+  """
+
+  alias Lux.Integrations.DefiAnalytics.DefiLlama
+  alias Lux.Integrations.DefiAnalytics.DuneAnalytics
+  alias Lux.Integrations.DefiAnalytics.Dashboard
+  alias Lux.Integrations.DefiAnalytics.AlertSystem
+
+  @type protocol_id :: String.t()
+  @type chain :: String.t()
+  @type timeframe :: :day | :week | :month | :year
+
+  # TVL Tracking
+
+  @doc """
+  Get current TVL for all protocols or a specific protocol.
+  """
+  @spec get_tvl(protocol_id() | nil) :: {:ok, map()} | {:error, term()}
+  def get_tvl(protocol_id \\ nil) do
+    DefiLlama.get_tvl(protocol_id)
+  end
+
+  @doc """
+  Get historical TVL data for a protocol.
+  """
+  @spec get_historical_tvl(protocol_id(), timeframe()) :: {:ok, list()} | {:error, term()}
+  def get_historical_tvl(protocol_id, timeframe \\ :month) do
+    DefiLlama.get_historical_tvl(protocol_id, timeframe)
+  end
+
+  @doc """
+  Get TVL for a specific chain.
+  """
+  @spec get_chain_tvl(chain()) :: {:ok, map()} | {:error, term()}
+  def get_chain_tvl(chain) do
+    DefiLlama.get_chain_tvl(chain)
+  end
+
+  # Protocol Metrics
+
+  @doc """
+  Get comprehensive metrics for a protocol.
+  """
+  @spec get_protocol_metrics(protocol_id()) :: {:ok, map()} | {:error, term()}
+  def get_protocol_metrics(protocol_id) do
+    DefiLlama.get_protocol_metrics(protocol_id)
+  end
+
+  @doc """
+  Get all protocols with their metrics.
+  """
+  @spec list_protocols() :: {:ok, list()} | {:error, term()}
+  def list_protocols do
+    DefiLlama.list_protocols()
+  end
+
+  # Yield Analytics
+
+  @doc """
+  Get yield data for pools.
+  """
+  @spec get_yields(filters :: map()) :: {:ok, list()} | {:error, term()}
+  def get_yields(filters \\ %{}) do
+    DefiLlama.get_yields(filters)
+  end
+
+  @doc """
+  Get yield history for a specific pool.
+  """
+  @spec get_yield_history(String.t(), timeframe()) :: {:ok, list()} | {:error, term()}
+  def get_yield_history(pool_id, timeframe \\ :month) do
+    DefiLlama.get_yield_history(pool_id, timeframe)
+  end
+
+  # Volume Analysis
+
+  @doc """
+  Get volume data for a protocol.
+  """
+  @spec get_volume(protocol_id(), timeframe()) :: {:ok, map()} | {:error, term()}
+  def get_volume(protocol_id, timeframe \\ :day) do
+    DefiLlama.get_volume(protocol_id, timeframe)
+  end
+
+  @doc """
+  Get DEX volumes across chains.
+  """
+  @spec get_dex_volumes(chain() | nil, timeframe()) :: {:ok, map()} | {:error, term()}
+  def get_dex_volumes(chain \\ nil, timeframe \\ :day) do
+    DefiLlama.get_dex_volumes(chain, timeframe)
+  end
+
+  # Custom Query Support (Dune Analytics)
+
+  @doc """
+  Execute a custom Dune Analytics query.
+  """
+  @spec execute_query(String.t(), map()) :: {:ok, map()} | {:error, term()}
+  def execute_query(query_sql, parameters \\ %{}) do
+    DuneAnalytics.execute_query(query_sql, parameters)
+  end
+
+  @doc """
+  Get results from a previously executed query.
+  """
+  @spec get_query_results(String.t()) :: {:ok, map()} | {:error, term()}
+  def get_query_results(query_id) do
+    DuneAnalytics.get_query_results(query_id)
+  end
+
+  @doc """
+  Execute a parameterized query with caching.
+  """
+  @spec execute_cached_query(String.t(), map(), integer()) :: {:ok, map()} | {:error, term()}
+  def execute_cached_query(query_sql, parameters \\ %{}, ttl_seconds \\ 300) do
+    DuneAnalytics.execute_cached_query(query_sql, parameters, ttl_seconds)
+  end
+
+  # Historical Data Access
+
+  @doc """
+  Get historical data with flexible parameters.
+  """
+  @spec get_historical_data(type :: atom(), protocol_id(), map()) :: {:ok, list()} | {:error, term()}
+  def get_historical_data(type, protocol_id, options \\ %{}) do
+    DefiLlama.get_historical_data(type, protocol_id, options)
+  end
+
+  # Dashboard
+
+  @doc """
+  Get dashboard data for a protocol.
+  """
+  @spec get_dashboard(protocol_id()) :: {:ok, map()} | {:error, term()}
+  def get_dashboard(protocol_id) do
+    Dashboard.generate(protocol_id)
+  end
+
+  @doc """
+  Get aggregated dashboard for multiple protocols.
+  """
+  @spec get_multi_protocol_dashboard(list(protocol_id())) :: {:ok, map()} | {:error, term()}
+  def get_multi_protocol_dashboard(protocol_ids) do
+    Dashboard.generate_multi(protocol_ids)
+  end
+
+  # Alert System
+
+  @doc """
+  Create a new alert.
+  """
+  @spec create_alert(map()) :: {:ok, map()} | {:error, term()}
+  def create_alert(alert_config) do
+    AlertSystem.create_alert(alert_config)
+  end
+
+  @doc """
+  Check all alerts and trigger notifications.
+  """
+  @spec check_alerts() :: {:ok, list()} | {:error, term()}
+  def check_alerts do
+    AlertSystem.check_alerts()
+  end
+
+  @doc """
+  List all active alerts.
+  """
+  @spec list_alerts()