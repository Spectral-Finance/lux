defmodule Lux.Prisms.Web3.DeFi.AnalyticsEngine do
  @moduledoc """
  DeFi analytics: protocol TVL tracking, yield comparison, risk scoring, portfolio analysis.

  Supports:
  - Protocol tracking with TVL snapshots (100 per protocol)
  - Portfolio management with weighted APY
  - Yield comparison across protocols
  - Risk scoring (audit, TVL, age, APY factors)

  ## Example

      {:ok, pid} = AnalyticsEngine.start_link()
      {:ok, p} = AnalyticsEngine.track_protocol(pid, %{name: "Aave", tvl: 10_000_000_000, apy: 5.2, audited: true})
      {:ok, risk} = AnalyticsEngine.risk_score(%{audited: true, tvl: 500_000_000, age_days: 500, apy: 5})
  """

  use GenServer

  defstruct [:protocols, :snapshots, :portfolio]

  @type protocol_id :: String.t()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec track_protocol(pid() | atom(), map()) :: {:ok, map()} | {:error, atom()}
  def track_protocol(pid \\ __MODULE__, params), do: GenServer.call(pid, {:track, params})

  @spec update_tvl(pid() | atom(), protocol_id(), number()) :: {:ok, map()} | {:error, atom()}
  def update_tvl(pid \\ __MODULE__, protocol_id, tvl), do: GenServer.call(pid, {:update_tvl, protocol_id, tvl})

  @spec list_protocols(pid() | atom()) :: {:ok, [map()]}
  def list_protocols(pid \\ __MODULE__), do: GenServer.call(pid, :list)

  @spec get_protocol(pid() | atom(), protocol_id()) :: {:ok, map()} | {:error, :not_found}
  def get_protocol(pid \\ __MODULE__, protocol_id), do: GenServer.call(pid, {:get, protocol_id})

  @spec add_to_portfolio(pid() | atom(), map()) :: {:ok, map()} | {:error, atom()}
  def add_to_portfolio(pid \\ __MODULE__, params), do: GenServer.call(pid, {:portfolio_add, params})

  @spec portfolio_summary(pid() | atom()) :: {:ok, map()}
  def portfolio_summary(pid \\ __MODULE__), do: GenServer.call(pid, :portfolio_summary)

  @spec compare_yields([map()]) :: {:ok, map()} | {:error, atom()}
  def compare_yields(protocols), do: do_compare_yields(protocols)

  @spec risk_score(map()) :: {:ok, map()}
  def risk_score(params), do: do_risk_score(params)

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{protocols: %{}, snapshots: %{}, portfolio: []}}

  @impl true
  def handle_call({:track, params}, _from, state) do
    cond do
      is_nil(params[:name]) -> {:reply, {:error, :missing_name}, state}
      params[:tvl] && params[:tvl] < 0 -> {:reply, {:error, :invalid_tvl}, state}
      true ->
        id = params[:id] || params[:name] || gen_id()
        protocol = %{
          id: id, name: params[:name], category: params[:category] || :lending,
          chain: params[:chain] || :ethereum, tvl: params[:tvl] || 0,
          apy: params[:apy] || 0, token: params[:token],
          audited: params[:audited] || false,
          tracked_at: DateTime.utc_now()
        }
        {:reply, {:ok, protocol}, %{state | protocols: Map.put(state.protocols, id, protocol)}}
    end
  end

  @impl true
  def handle_call({:update_tvl, pid, tvl}, _from, state) do
    cond do
      tvl < 0 -> {:reply, {:error, :invalid_tvl}, state}
      true ->
        case Map.get(state.protocols, pid) do
          nil -> {:reply, {:error, :not_found}, state}
          protocol ->
            updated = %{protocol | tvl: tvl}
            snapshot = %{protocol_id: pid, tvl: tvl, at: DateTime.utc_now()}
            snapshots = Map.update(state.snapshots, pid, [snapshot], &[snapshot | Enum.take(&1, 99)])
            {:reply, {:ok, updated}, %{state | protocols: Map.put(state.protocols, pid, updated), snapshots: snapshots}}
        end
    end
  end

  @impl true
  def handle_call(:list, _from, state), do: {:reply, {:ok, Map.values(state.protocols)}, state}

  @impl true
  def handle_call({:get, pid}, _from, state) do
    case Map.get(state.protocols, pid) do
      nil -> {:reply, {:error, :not_found}, state}
      p -> {:reply, {:ok, p}, state}
    end
  end

  @impl true
  def handle_call({:portfolio_add, params}, _from, state) do
    cond do
      is_nil(params[:protocol]) -> {:reply, {:error, :missing_protocol}, state}
      params[:amount] && params[:amount] < 0 -> {:reply, {:error, :invalid_amount}, state}
      true ->
        entry = %{protocol: params[:protocol], amount: params[:amount] || 0, apy: params[:apy] || 0, added_at: DateTime.utc_now()}
        {:reply, {:ok, entry}, %{state | portfolio: [entry | state.portfolio]}}
    end
  end

  @impl true
  def handle_call(:portfolio_summary, _from, state) do
    total = Enum.sum(Enum.map(state.portfolio, & &1.amount))
    weighted_apy = if total > 0 do
      Enum.sum(Enum.map(state.portfolio, fn e -> e.amount * e.apy end)) / total
    else
      0.0
    end

    {:reply, {:ok, %{
      total_value: total,
      positions: length(state.portfolio),
      weighted_apy: Float.round(weighted_apy, 2),
      daily_yield: Float.round(total * weighted_apy / 100 / 365, 2)
    }}, state}
  end

  defp do_compare_yields([]), do: {:error, :empty_list}
  defp do_compare_yields(protocols) when is_list(protocols) do
    sorted = Enum.sort_by(protocols, & &1[:apy] || 0, :desc)
    {:ok, %{
      ranked: Enum.map(sorted, &Map.take(&1, [:name, :apy, :tvl, :chain])),
      best: hd(sorted)[:name],
      avg_apy: Float.round(Enum.sum(Enum.map(protocols, & &1[:apy] || 0)) / length(protocols), 2)
    }}
  end

  defp do_risk_score(params) do
    score = 0
    score = score + if(params[:audited], do: 0, else: 30)
    score = score + cond do
      (params[:tvl] || 0) > 100_000_000 -> 0
      (params[:tvl] || 0) > 10_000_000 -> 10
      true -> 30
    end
    score = score + cond do
      (params[:age_days] || 0) > 365 -> 0
      (params[:age_days] || 0) > 90 -> 10
      true -> 20
    end
    score = score + cond do
      (params[:apy] || 0) > 100 -> 30
      (params[:apy] || 0) > 30 -> 10
      true -> 0
    end

    level = cond do
      score >= 60 -> :high
      score >= 30 -> :medium
      true -> :low
    end

    {:ok, %{score: score, level: level, max_score: 110}}
  end

  defp gen_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
