defmodule Lux.Prisms.Web3.Curve.PoolManager do
  @moduledoc """
  Curve Finance stablecoin pool management.

  Supports:
  - Add/remove liquidity with partial withdrawal
  - Gauge staking/unstaking for CRV rewards
  - Reward claiming
  - Pool analysis (APR, utilization, risk scoring)

  ## Example

      {:ok, pid} = PoolManager.start_link()
      {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", tokens: ["DAI", "USDC", "USDT"], amounts: [1000, 1000, 1000], lp_amount: 3000.0})
      {:ok, _} = PoolManager.stake_gauge(pid, pos.id)
      {:ok, analysis} = PoolManager.analyze_pool(%{tvl: 500_000_000, volume_24h: 50_000_000})
  """

  use GenServer

  defstruct [:positions, :gauges, :rewards]

  @type position_id :: String.t()

  # --- Public API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec add_liquidity(pid() | atom(), map()) :: {:ok, map()} | {:error, atom()}
  def add_liquidity(pid \\ __MODULE__, params), do: GenServer.call(pid, {:add_liquidity, params})

  @spec remove_liquidity(pid() | atom(), position_id(), number()) :: {:ok, map()} | {:error, atom()}
  def remove_liquidity(pid \\ __MODULE__, position_id, pct \\ 100), do: GenServer.call(pid, {:remove_liquidity, position_id, pct})

  @spec stake_gauge(pid() | atom(), position_id()) :: {:ok, map()} | {:error, atom()}
  def stake_gauge(pid \\ __MODULE__, position_id), do: GenServer.call(pid, {:stake_gauge, position_id})

  @spec unstake_gauge(pid() | atom(), position_id()) :: {:ok, map()} | {:error, atom()}
  def unstake_gauge(pid \\ __MODULE__, position_id), do: GenServer.call(pid, {:unstake_gauge, position_id})

  @spec claim_rewards(pid() | atom(), position_id()) :: {:ok, map()} | {:error, atom()}
  def claim_rewards(pid \\ __MODULE__, position_id), do: GenServer.call(pid, {:claim_rewards, position_id})

  @spec get_position(pid() | atom(), position_id()) :: {:ok, map()} | {:error, :not_found}
  def get_position(pid \\ __MODULE__, position_id), do: GenServer.call(pid, {:get, position_id})

  @spec list_positions(pid() | atom()) :: {:ok, [map()]}
  def list_positions(pid \\ __MODULE__), do: GenServer.call(pid, :list)

  @spec analyze_pool(map()) :: {:ok, map()} | {:error, atom()}
  def analyze_pool(params), do: do_analyze_pool(params)

  # --- Callbacks ---

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{positions: %{}, gauges: %{}, rewards: %{}}}

  @impl true
  def handle_call({:add_liquidity, params}, _from, state) do
    cond do
      is_nil(params[:pool]) ->
        {:reply, {:error, :missing_pool}, state}
      params[:lp_amount] && params[:lp_amount] < 0 ->
        {:reply, {:error, :negative_amount}, state}
      true ->
        id = gen_id()
        position = %{
          id: id, pool: params[:pool], tokens: params[:tokens] || [],
          amounts: params[:amounts] || [], lp_tokens: params[:lp_amount] || 0,
          staked: false, rewards_earned: %{crv: 0, extra: []},
          status: :active, created_at: DateTime.utc_now()
        }
        {:reply, {:ok, position}, %{state | positions: Map.put(state.positions, id, position)}}
    end
  end

  @impl true
  def handle_call({:remove_liquidity, pos_id, pct}, _from, state) do
    cond do
      pct <= 0 or pct > 100 ->
        {:reply, {:error, :invalid_percentage}, state}
      true ->
        with_position(state, pos_id, fn pos ->
          if pos.status == :closed do
            {:reply, {:error, :position_closed}, state}
          else
            removed = Float.round(pos.lp_tokens * pct / 100, 6)
            remaining = Float.round(pos.lp_tokens - removed, 6)
            updated = if remaining <= 0, do: %{pos | lp_tokens: 0, status: :closed}, else: %{pos | lp_tokens: remaining}
            new_state = put_pos(state, pos_id, updated)
            {:reply, {:ok, %{removed_lp: removed, remaining_lp: remaining, position: updated}}, new_state}
          end
        end)
    end
  end

  @impl true
  def handle_call({:stake_gauge, pos_id}, _from, state) do
    with_position(state, pos_id, fn pos ->
      cond do
        pos.status == :closed -> {:reply, {:error, :position_closed}, state}
        pos.staked -> {:reply, {:error, :already_staked}, state}
        true ->
          updated = %{pos | staked: true}
          {:reply, {:ok, updated}, put_pos(state, pos_id, updated)}
      end
    end)
  end

  @impl true
  def handle_call({:unstake_gauge, pos_id}, _from, state) do
    with_position(state, pos_id, fn pos ->
      if pos.staked do
        updated = %{pos | staked: false}
        {:reply, {:ok, updated}, put_pos(state, pos_id, updated)}
      else
        {:reply, {:error, :not_staked}, state}
      end
    end)
  end

  @impl true
  def handle_call({:claim_rewards, pos_id}, _from, state) do
    with_position(state, pos_id, fn pos ->
      rewards = pos.rewards_earned
      updated = %{pos | rewards_earned: %{crv: 0, extra: []}}
      {:reply, {:ok, %{claimed: rewards}}, put_pos(state, pos_id, updated)}
    end)
  end

  @impl true
  def handle_call({:get, pos_id}, _from, state) do
    case Map.get(state.positions, pos_id) do
      nil -> {:reply, {:error, :not_found}, state}
      pos -> {:reply, {:ok, pos}, state}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, {:ok, Map.values(state.positions)}, state}
  end

  # --- Private ---

  defp do_analyze_pool(params) do
    tvl = params[:tvl] || 0
    volume_24h = params[:volume_24h] || 0
    fee_rate = params[:fee_rate] || 0.0004
    num_tokens = params[:num_tokens] || 2

    cond do
      tvl < 0 -> {:error, :invalid_tvl}
      volume_24h < 0 -> {:error, :invalid_volume}
      true ->
        daily_fees = volume_24h * fee_rate
        apr = if tvl > 0, do: Float.round(daily_fees * 365 / tvl * 100, 2), else: 0.0
        utilization = if tvl > 0, do: Float.round(volume_24h / tvl * 100, 2), else: 0.0

        {:ok, %{
          apr_estimate: apr,
          daily_fees: Float.round(daily_fees, 2),
          utilization: utilization,
          risk_score: risk_score(tvl, num_tokens),
          recommendation: cond do
            apr > 10 -> :very_attractive
            apr > 5 -> :attractive
            apr > 2 -> :moderate
            true -> :low_yield
          end
        }}
    end
  end

  defp risk_score(tvl, num_tokens) do
    base = cond do
      tvl > 100_000_000 -> 10
      tvl > 10_000_000 -> 30
      tvl > 1_000_000 -> 50
      true -> 80
    end
    base + max((num_tokens - 2) * 5, 0)
  end

  defp with_position(state, pos_id, fun) do
    case Map.get(state.positions, pos_id) do
      nil -> {:reply, {:error, :not_found}, state}
      pos -> fun.(pos)
    end
  end

  defp put_pos(state, id, pos), do: %{state | positions: Map.put(state.positions, id, pos)}
  defp gen_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
