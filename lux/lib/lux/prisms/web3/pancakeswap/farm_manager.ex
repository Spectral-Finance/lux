defmodule Lux.Prisms.Web3.PancakeSwap.FarmManager do
  @moduledoc """
  PancakeSwap integration: yield farming, CAKE staking, swap estimation, farm analysis.

  Supports:
  - Farm position management (add/remove with lifecycle)
  - CAKE staking/unstaking with balance tracking
  - Reward harvesting
  - Swap estimation with fee and slippage
  - Farm APR/risk analysis

  ## Example

      {:ok, pid} = FarmManager.start_link()
      {:ok, farm} = FarmManager.add_farm(pid, %{pair: "CAKE-BNB", lp_amount: 100.0, apr: 45.0})
      {:ok, _} = FarmManager.stake_cake(pid, 1000)
      {:ok, est} = FarmManager.estimate_swap(%{amount_in: 100, price: 2.5})
  """

  use GenServer

  defstruct [:farms, :pools, :staking]

  @type farm_id :: String.t()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec add_farm(pid() | atom(), map()) :: {:ok, map()} | {:error, atom()}
  def add_farm(pid \\ __MODULE__, params), do: GenServer.call(pid, {:add_farm, params})

  @spec remove_farm(pid() | atom(), farm_id()) :: {:ok, map()} | {:error, atom()}
  def remove_farm(pid \\ __MODULE__, farm_id), do: GenServer.call(pid, {:remove_farm, farm_id})

  @spec stake_cake(pid() | atom(), number()) :: {:ok, map()} | {:error, atom()}
  def stake_cake(pid \\ __MODULE__, amount), do: GenServer.call(pid, {:stake_cake, amount})

  @spec unstake_cake(pid() | atom(), number()) :: {:ok, map()} | {:error, atom()}
  def unstake_cake(pid \\ __MODULE__, amount), do: GenServer.call(pid, {:unstake_cake, amount})

  @spec harvest(pid() | atom(), farm_id()) :: {:ok, map()} | {:error, atom()}
  def harvest(pid \\ __MODULE__, farm_id), do: GenServer.call(pid, {:harvest, farm_id})

  @spec list_farms(pid() | atom()) :: {:ok, [map()]}
  def list_farms(pid \\ __MODULE__), do: GenServer.call(pid, :list_farms)

  @spec get_staking(pid() | atom()) :: {:ok, map()}
  def get_staking(pid \\ __MODULE__), do: GenServer.call(pid, :get_staking)

  @spec estimate_swap(map()) :: {:ok, map()} | {:error, atom()}
  def estimate_swap(params), do: do_estimate_swap(params)

  @spec analyze_farm(map()) :: {:ok, map()}
  def analyze_farm(params), do: do_analyze_farm(params)

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{farms: %{}, pools: %{}, staking: %{staked: 0, rewards: 0}}}

  @impl true
  def handle_call({:add_farm, params}, _from, state) do
    cond do
      is_nil(params[:pair]) -> {:reply, {:error, :missing_pair}, state}
      params[:lp_amount] && params[:lp_amount] < 0 -> {:reply, {:error, :negative_amount}, state}
      true ->
        id = gen_id()
        farm = %{
          id: id, pair: params[:pair], lp_amount: params[:lp_amount] || 0,
          rewards_earned: 0, apr: params[:apr] || 0, multiplier: params[:multiplier] || "1x",
          chain: params[:chain] || :bsc, status: :active, created_at: DateTime.utc_now()
        }
        {:reply, {:ok, farm}, %{state | farms: Map.put(state.farms, id, farm)}}
    end
  end

  @impl true
  def handle_call({:remove_farm, farm_id}, _from, state) do
    case Map.get(state.farms, farm_id) do
      nil -> {:reply, {:error, :not_found}, state}
      %{status: :withdrawn} -> {:reply, {:error, :already_withdrawn}, state}
      farm ->
        updated = %{farm | status: :withdrawn}
        {:reply, {:ok, updated}, %{state | farms: Map.put(state.farms, farm_id, updated)}}
    end
  end

  @impl true
  def handle_call({:stake_cake, amount}, _from, state) when amount <= 0 do
    {:reply, {:error, :invalid_amount}, state}
  end

  def handle_call({:stake_cake, amount}, _from, state) do
    staking = %{state.staking | staked: state.staking.staked + amount}
    {:reply, {:ok, staking}, %{state | staking: staking}}
  end

  @impl true
  def handle_call({:unstake_cake, amount}, _from, state) when amount <= 0 do
    {:reply, {:error, :invalid_amount}, state}
  end

  def handle_call({:unstake_cake, amount}, _from, state) do
    actual = min(amount, state.staking.staked)
    if actual == 0 do
      {:reply, {:error, :nothing_staked}, state}
    else
      staking = %{state.staking | staked: state.staking.staked - actual}
      {:reply, {:ok, %{unstaked: actual, remaining: staking.staked}}, %{state | staking: staking}}
    end
  end

  @impl true
  def handle_call({:harvest, farm_id}, _from, state) do
    case Map.get(state.farms, farm_id) do
      nil -> {:reply, {:error, :not_found}, state}
      farm ->
        rewards = farm.rewards_earned
        updated = %{farm | rewards_earned: 0}
        {:reply, {:ok, %{harvested: rewards}}, %{state | farms: Map.put(state.farms, farm_id, updated)}}
    end
  end

  @impl true
  def handle_call(:list_farms, _from, state), do: {:reply, {:ok, Map.values(state.farms)}, state}

  @impl true
  def handle_call(:get_staking, _from, state), do: {:reply, {:ok, state.staking}, state}

  defp do_estimate_swap(params) do
    amount_in = params[:amount_in] || 0
    price = params[:price] || 1.0

    cond do
      amount_in <= 0 -> {:error, :invalid_amount}
      price <= 0 -> {:error, :invalid_price}
      true ->
        fee_rate = params[:fee_rate] || 0.0025
        slippage = params[:slippage] || 0.005
        amount_out = amount_in * price * (1 - fee_rate) * (1 - slippage)
        {:ok, %{
          amount_in: amount_in, amount_out: Float.round(amount_out, 6),
          fee: Float.round(amount_in * fee_rate, 6), price_impact: Float.round(slippage * 100, 2)
        }}
    end
  end

  defp do_analyze_farm(params) do
    apr = params[:apr] || 0
    tvl = params[:tvl] || 0
    multiplier = params[:multiplier] || "1x"

    risk = cond do
      tvl > 10_000_000 -> :low
      tvl > 1_000_000 -> :medium
      true -> :high
    end

    {:ok, %{apr: apr, tvl: tvl, multiplier: multiplier, risk: risk, daily_yield: Float.round(apr / 365, 4)}}
  end

  defp gen_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
