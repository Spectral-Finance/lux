defmodule Lux.TwitterAnalytics.Supervisor do
  @moduledoc """
  Top-level supervisor for Twitter Analytics system.

  Manages all analytics components:
  - Aggregator (data aggregation)
  - MetricsCollector (data collection)
  - Reporter (report generation)
  - AlertManager (threshold monitoring)
  """
  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting TwitterAnalytics.Supervisor")

    children = [
      # Core aggregation
      Lux.TwitterAnalytics.Aggregator,

      # Data collection
      Lux.TwitterAnalytics.MetricsCollector,

      # Reporting
      Lux.TwitterAnalytics.Reporter,

      # Alert management
      Lux.TwitterAnalytics.AlertManager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
