defmodule Lux.Prisms.Twitter.Analytics.AlertSystem do
  @moduledoc """
  Alert system for Twitter engagement thresholds.

  Features:
  - Define threshold alerts (e.g., tweet gets > 100 likes)
  - Follower milestone alerts
  - Negative sentiment spike alerts
  - Custom metric alerts
  """

  use GenServer

  defstruct [:alerts, :triggered, :handlers]

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def add_alert(pid \\ __MODULE__, alert) do
    GenServer.call(pid, {:add_alert, alert})
  end

  def remove_alert(pid \\ __MODULE__, alert_id) do
    GenServer.call(pid, {:remove_alert, alert_id})
  end

  def check(pid \\ __MODULE__, metrics) do
    GenServer.call(pid, {:check, metrics})
  end

  def list_alerts(pid \\ __MODULE__) do
    GenServer.call(pid, :list_alerts)
  end

  def get_triggered(pid \\ __MODULE__) do
    GenServer.call(pid, :get_triggered)
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{
      alerts: [],
      triggered: [],
      handlers: %{}
    }}
  end

  @impl true
  def handle_call({:add_alert, alert}, _from, state) do
    id = alert[:id] || :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    entry = %{
      id: id,
      name: alert[:name] || "Alert #{id}",
      metric: alert[:metric],
      operator: alert[:operator] || :gte,
      threshold: alert[:threshold],
      enabled: alert[:enabled] != false
    }
    {:reply, {:ok, entry}, %{state | alerts: [entry | state.alerts]}}
  end

  @impl true
  def handle_call({:remove_alert, alert_id}, _from, state) do
    alerts = Enum.reject(state.alerts, &(&1.id == alert_id))
    {:reply, :ok, %{state | alerts: alerts}}
  end

  @impl true
  def handle_call({:check, metrics}, _from, state) do
    newly_triggered = state.alerts
    |> Enum.filter(& &1.enabled)
    |> Enum.filter(fn alert ->
      value = Map.get(metrics, alert.metric, 0)
      compare(value, alert.operator, alert.threshold)
    end)
    |> Enum.map(fn alert ->
      %{alert_id: alert.id, alert_name: alert.name, metric: alert.metric,
        threshold: alert.threshold, value: Map.get(metrics, alert.metric, 0),
        triggered_at: DateTime.utc_now()}
    end)

    {:reply, {:ok, newly_triggered},
     %{state | triggered: newly_triggered ++ Enum.take(state.triggered, 999)}}
  end

  @impl true
  def handle_call(:list_alerts, _from, state) do
    {:reply, {:ok, state.alerts}, state}
  end

  @impl true
  def handle_call(:get_triggered, _from, state) do
    {:reply, {:ok, state.triggered}, state}
  end

  defp compare(value, :gte, threshold), do: value >= threshold
  defp compare(value, :gt, threshold), do: value > threshold
  defp compare(value, :lte, threshold), do: value <= threshold
  defp compare(value, :lt, threshold), do: value < threshold
  defp compare(value, :eq, threshold), do: value == threshold
  defp compare(_, _, _), do: false
end
