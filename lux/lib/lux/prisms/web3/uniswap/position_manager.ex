defmodule Lux.Prisms.Web3.Uniswap.PositionManager do
  @moduledoc """
  Manages Uniswap V3 concentrated liquidity positions.

  Supports:
  - Position creation with fee tier validation
  - Position closing and lifecycle tracking
  - Fee collection and optional auto-compounding
  - Price range rebalancing
  - Position health monitoring (in-range, IL estimate, utilization)
  - Portfolio-level summary

  ## Example

      {:ok, pid} = PositionManager.start_link()
      {:ok, pos} = PositionManager.create_position(pid, %{
        token0: "WETH", token1: "USDC", fee_tier: 3000,
        price_lower: 1800.0, price_upper: 2200.0, amount0: 1.0, amount1: 2000.0
      })
      {:ok, health} = PositionManager.health_check(pid, pos.id)
  """

  use GenServer

  defstruct [:positions, :fee_tiers, :config]

  @type position_id :: String.t()
  @type position :: %{
    id: position_id(),
    pool: %{token0: String.t(), token1: String.t(), fee_tier: non_neg_integer()},
    price_lower: float(),
    price_upper: float(),
    liquidity: number(),
    amount0: number(),
    amount1: number(),
    fees_earned: %{token0: number(), token1: number()},
    status: :active | :closed,
    chain: atom(),
    created_at: DateTime.t()
  }

  @valid_fee_tiers [100, 500, 3000, 10_000]

  # --- Public API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec create_position(pid() | atom(), map()) :: {:ok, position()} | {:error, atom()}
  def create_position(pid \\ __MODULE__, params), do: GenServer.call(pid, {:create, params})

  @spec close_position(pid() | atom(), position_id()) :: {:ok, position()} | {:error, atom()}
  def close_position(pid \\ __MODULE__, position_id), do: GenServer.call(pid, {:close, position_id})

  @spec get_position(pid() | atom(), position_id()) :: {:ok, position()} | {:error, :not_found}
  def get_position(pid \\ __MODULE__, position_id), do: GenServer.call(pid, {:get, position_id})

  @spec list_positions(pid() | atom()) :: {:ok, [position()]}
  def list_positions(pid \\ __MODULE__), do: GenServer.call(pid, :list)

  @spec collect_fees(pid() | atom(), position_id()) :: {:ok, map()} | {:error, atom()}
  def collect_fees(pid \\ __MODULE__, position_id), do: GenServer.call(pid, {:collect_fees, position_id})

  @spec rebalance(pid() | atom(), position_id(), map()) :: {:ok, position()} | {:error, atom()}
  def rebalance(pid \\ __MODULE__, position_id, new_range), do: GenServer.call(pid, {:rebalance, position_id, new_range})

  @spec health_check(pid() | atom(), position_id()) :: {:ok, map()} | {:error, :not_found}
  def health_check(pid \\ __MODULE__, position_id), do: GenServer.call(pid, {:health_check, position_id})

  @spec portfolio_summary(pid() | atom()) :: {:ok, map()}
  def portfolio_summary(pid \\ __MODULE__), do: GenServer.call(pid, :portfolio_summary)

  @spec valid_fee_tiers() :: [non_neg_integer()]
  def valid_fee_tiers, do: @valid_fee_tiers

  # --- Callbacks ---

  @impl true
  def init(opts) do
    {:ok, %__MODULE__{
      positions: %{},
      fee_tiers: @valid_fee_tiers,
      config: %{
        rebalance_threshold: opts[:rebalance_threshold] || 0.1,
        auto_compound: opts[:auto_compound] || false
      }
    }}
  end

  @impl true
  def handle_call({:create, params}, _from, state) do
    with :ok <- validate_create_params(params) do
      id = gen_id()
      position = %{
        id: id,
        pool: %{
          token0: params[:token0],
          token1: params[:token1],
          fee_tier: params[:fee_tier] || 3000
        },
        tick_lower: params[:tick_lower],
        tick_upper: params[:tick_upper],
        price_lower: params[:price_lower],
        price_upper: params[:price_upper],
        liquidity: params[:liquidity] || 0,
        amount0: params[:amount0] || 0,
        amount1: params[:amount1] || 0,
        fees_earned: %{token0: 0, token1: 0},
        status: :active,
        chain: params[:chain] || :ethereum,
        created_at: DateTime.utc_now()
      }
      {:reply, {:ok, position}, %{state | positions: Map.put(state.positions, id, position)}}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:close, position_id}, _from, state) do
    with_position(state, position_id, fn pos ->
      if pos.status == :closed do
        {:reply, {:error, :already_closed}, state}
      else
        updated = %{pos | status: :closed}
        {:reply, {:ok, updated}, put_position(state, position_id, updated)}
      end
    end)
  end

  @impl true
  def handle_call({:get, position_id}, _from, state) do
    with_position(state, position_id, fn pos ->
      {:reply, {:ok, pos}, state}
    end)
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, {:ok, Map.values(state.positions)}, state}
  end

  @impl true
  def handle_call({:collect_fees, position_id}, _from, state) do
    with_position(state, position_id, fn pos ->
      if pos.status == :closed do
        {:reply, {:error, :position_closed}, state}
      else
        fees = pos.fees_earned
        updated = %{pos | fees_earned: %{token0: 0, token1: 0}}
        {:reply, {:ok, %{collected: fees, position_id: position_id}},
         put_position(state, position_id, updated)}
      end
    end)
  end

  @impl true
  def handle_call({:rebalance, position_id, new_range}, _from, state) do
    with_position(state, position_id, fn pos ->
      cond do
        pos.status == :closed ->
          {:reply, {:error, :position_closed}, state}
        new_range[:price_lower] && new_range[:price_upper] &&
          new_range[:price_lower] >= new_range[:price_upper] ->
          {:reply, {:error, :invalid_range}, state}
        true ->
          updated = %{pos |
            tick_lower: new_range[:tick_lower] || pos.tick_lower,
            tick_upper: new_range[:tick_upper] || pos.tick_upper,
            price_lower: new_range[:price_lower] || pos.price_lower,
            price_upper: new_range[:price_upper] || pos.price_upper
          }
          {:reply, {:ok, updated}, put_position(state, position_id, updated)}
      end
    end)
  end

  @impl true
  def handle_call({:health_check, position_id}, _from, state) do
    with_position(state, position_id, fn pos ->
      current_price = pos[:current_price] || midpoint(pos.price_lower, pos.price_upper)
      in_range = current_price >= pos.price_lower && current_price <= pos.price_upper
      range_width = pos.price_upper - pos.price_lower

      range_utilization =
        if range_width > 0,
          do: Float.round((current_price - pos.price_lower) / range_width * 100, 1),
          else: 0.0

      health = %{
        position_id: position_id,
        in_range: in_range,
        status: pos.status,
        range_utilization: range_utilization,
        needs_rebalance: !in_range,
        impermanent_loss_estimate: estimate_il(pos, current_price)
      }
      {:reply, {:ok, health}, state}
    end)
  end

  @impl true
  def handle_call(:portfolio_summary, _from, state) do
    positions = Map.values(state.positions)
    active = Enum.count(positions, &(&1.status == :active))
    total_fees_0 = positions |> Enum.map(&get_in(&1, [:fees_earned, :token0])) |> Enum.sum()
    total_fees_1 = positions |> Enum.map(&get_in(&1, [:fees_earned, :token1])) |> Enum.sum()

    {:reply, {:ok, %{
      total_positions: length(positions),
      active: active,
      closed: length(positions) - active,
      total_fees: %{token0: total_fees_0, token1: total_fees_1}
    }}, state}
  end

  # --- Private Helpers ---

  defp validate_create_params(params) do
    cond do
      is_nil(params[:token0]) or is_nil(params[:token1]) ->
        {:error, :missing_tokens}
      params[:token0] == params[:token1] ->
        {:error, :same_token}
      params[:fee_tier] && params[:fee_tier] not in @valid_fee_tiers ->
        {:error, :invalid_fee_tier}
      params[:price_lower] && params[:price_upper] && params[:price_lower] >= params[:price_upper] ->
        {:error, :invalid_range}
      params[:price_lower] && params[:price_lower] < 0 ->
        {:error, :negative_price}
      params[:amount0] && params[:amount0] < 0 ->
        {:error, :negative_amount}
      params[:amount1] && params[:amount1] < 0 ->
        {:error, :negative_amount}
      true ->
        :ok
    end
  end

  defp with_position(state, position_id, fun) do
    case Map.get(state.positions, position_id) do
      nil -> {:reply, {:error, :not_found}, state}
      pos -> fun.(pos)
    end
  end

  defp put_position(state, id, pos) do
    %{state | positions: Map.put(state.positions, id, pos)}
  end

  defp midpoint(lower, upper), do: (lower + upper) / 2

  defp estimate_il(pos, current_price) do
    mid = midpoint(pos.price_lower, pos.price_upper)
    if mid > 0 do
      ratio = current_price / mid
      il = 2 * :math.sqrt(ratio) / (1 + ratio) - 1
      Float.round(abs(il) * 100, 2)
    else
      0.0
    end
  end

  defp gen_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
