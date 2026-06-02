defmodule Lux.Integrations.Hyperliquid.MarginManager do
  @moduledoc """
  GenServer for managing margin and leverage on Hyperliquid.

  Provides functions for adding/removing margin, switching between
  cross and isolated margin modes, and adjusting leverage.

  ## Usage

      {:ok, pid} = MarginManager.start_link(name: MyMarginManager)

      # Add margin to a position
      MarginManager.add_margin(pid, "ETH", "100")

      # Remove margin from a position
      MarginManager.remove_margin(pid, "ETH", "50")

      # Set leverage
      MarginManager.set_leverage(pid, "ETH", 5)

      # Switch to cross margin
      MarginManager.set_margin_mode(pid, "ETH", :cross)

      # Get margin summary
      MarginManager.get_margin_summary(pid)
  """

  use GenServer

  require Logger

  alias Lux.Config
  alias Lux.Integrations.Hyperliquid.Client
  alias Lux.Integrations.Hyperliquid.Models

  @type margin_mode :: :cross | :isolated

  @doc false
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Adds margin to an isolated position.

  ## Parameters

    * `pid` — The MarginManager process
    * `asset` — Trading pair
    * `amount` — USD amount to add (as string or float)
  """
  @spec add_margin(pid() | atom(), String.t(), String.t()) :: {:ok, term()} | {:error, term()}
  def add_margin(pid, asset, amount) do
    GenServer.call(pid, {:add_margin, asset, amount})
  end

  @doc """
  Removes margin from an isolated position.

  ## Parameters

    * `pid` — The MarginManager process
    * `asset` — Trading pair
    * `amount` — USD amount to remove
  """
  @spec remove_margin(pid() | atom(), String.t(), String.t()) :: {:ok, term()} | {:error, term()}
  def remove_margin(pid, asset, amount) do
    GenServer.call(pid, {:remove_margin, asset, amount})
  end

  @doc """
  Sets the leverage for a position.

  ## Parameters

    * `pid` — The MarginManager process
    * `asset` — Trading pair
    * `leverage` — New leverage value (integer, e.g., 5 for 5x)
  """
  @spec set_leverage(pid() | atom(), String.t(), integer()) :: {:ok, term()} | {:error, term()}
  def set_leverage(pid, asset, leverage) do
    GenServer.call(pid, {:set_leverage, asset, leverage})
  end

  @doc """
  Sets the margin mode for a position.

  ## Parameters

    * `pid` — The MarginManager process
    * `asset` — Trading pair
    * `mode` — `:cross` or `:isolated`
  """
  @spec set_margin_mode(pid() | atom(), String.t(), margin_mode()) :: {:ok, term()} | {:error, term()}
  def set_margin_mode(pid, asset, mode) do
    GenServer.call(pid, {:set_margin_mode, asset, mode})
  end

  @doc """
  Gets the current margin summary for the account.
  """
  @spec get_margin_summary(pid() | atom()) :: {:ok, map()} | {:error, term()}
  def get_margin_summary(pid) do
    GenServer.call(pid, :get_margin_summary)
  end

  @doc """
  Returns the account's available margin (withdrawable balance).
  """
  @spec get_available_margin(pid() | atom()) :: {:ok, float()} | {:error, term()}
  def get_available_margin(pid) do
    GenServer.call(pid, :get_available_margin)
  end

  @doc """
  Returns the current margin ratio.
  """
  @spec get_margin_ratio(pid() | atom()) :: {:ok, float()} | {:error, term()}
  def get_margin_ratio(pid) do
    GenServer.call(pid, :get_margin_ratio)
  end

  @impl true
  def init(opts) do
    state = %{
      address: Config.hyperliquid_account_address(),
      account_value: 0.0,
      total_margin_used: 0.0,
      total_ntl_pos: 0.0,
      total_raw_usd: 0.0,
      maintenance_margin_ratio: 0.0,
      withdrawable: 0.0,
      position_margins: %{},
      asset_leverages: %{},
      last_sync: nil
    }

    Logger.info("[MarginManager] Initialized")

    {:ok, state}
  end

  @impl true
  def handle_call({:add_margin, asset, amount}, _from, state) do
    params = %{
      is_deposit: true,
      amount: to_string(amount)
    }

    result =
      case Client.modify_margin(asset, params) do
        {:ok, response} ->
          Logger.info("[MarginManager] Added #{amount} margin to #{asset}")
          {:ok, %Models.MarginChange{
            asset: asset,
            amount: to_string(amount),
            is_deposit: true,
            status: "success",
            hash: response["hash"]
          }}

        {:error, reason} ->
          Logger.error("[MarginManager] Failed to add margin to #{asset}: #{inspect(reason)}")
          {:error, reason}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:remove_margin, asset, amount}, _from, state) do
    params = %{
      is_deposit: false,
      amount: to_string(amount)
    }

    result =
      case Client.modify_margin(asset, params) do
        {:ok, response} ->
          Logger.info("[MarginManager] Removed #{amount} margin from #{asset}")
          {:ok, %Models.MarginChange{
            asset: asset,
            amount: to_string(amount),
            is_deposit: false,
            status: "success",
            hash: response["hash"]
          }}

        {:error, reason} ->
          Logger.error("[MarginManager] Failed to remove margin from #{asset}: #{inspect(reason)}")
          {:error, reason}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:set_leverage, asset, leverage}, _from, state) do
    is_cross = Map.get(state.position_margins, asset, %{}) |> Map.get(:mode, "cross") == "cross"

    params = %{
      leverage: leverage,
      is_cross: is_cross
    }

    result =
      case Client.modify_margin(asset, params) do
        {:ok, response} ->
          Logger.info("[MarginManager] Set leverage for #{asset} to #{leverage}x")

          updated_leverages = Map.put(state.asset_leverages, asset, leverage)

          {:reply, {:ok, response}, %{state | asset_leverages: updated_leverages}}

        {:error, reason} ->
          Logger.error("[MarginManager] Failed to set leverage for #{asset}: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
  end

  @impl true
  def handle_call({:set_margin_mode, asset, mode}, _from, state) do
    mode_str = case mode do
      :cross -> "cross"
      :isolated -> "isolated"
    end

    current_leverage = Map.get(state.asset_leverages, asset, 1)

    params = %{
      leverage: current_leverage,
      is_cross: mode == :cross
    }

    result =
      case Client.modify_margin(asset, params) do
        {:ok, response} ->
          Logger.info("[MarginManager] Set margin mode for #{asset} to #{mode_str} (leverage: #{current_leverage}x)")

          updated_margins = Map.put(state.position_margins, asset, %{
            mode: mode_str,
            updated_at: System.system_time(:millisecond)
          })

          {:reply, {:ok, response}, %{state | position_margins: updated_margins}}

        {:error, reason} ->
          Logger.error("[MarginManager] Failed to set margin mode for #{asset}: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
  end

  @impl true
  def handle_call(:get_margin_summary, _from, state) do
    summary = %{
      account_value: state.account_value,
      total_margin_used: state.total_margin_used,
      total_ntl_pos: state.total_ntl_pos,
      total_raw_usd: state.total_raw_usd,
      maintenance_margin_ratio: state.maintenance_margin_ratio,
      withdrawable: state.withdrawable,
      margin_ratio: compute_margin_ratio(state),
      available_margin: state.account_value - state.total_margin_used,
      position_margins: state.position_margins,
      last_sync: state.last_sync
    }

    {:reply, {:ok, summary}, state}
  end

  @impl true
  def handle_call(:get_available_margin, _from, state) do
    available = if state.account_value > state.total_margin_used do
      state.account_value - state.total_margin_used
    else
      0.0
    end

    {:reply, {:ok, available}, state}
  end

  @impl true
  def handle_call(:get_margin_ratio, _from, state) do
    {:reply, {:ok, compute_margin_ratio(state)}, state}
  end

  defp compute_margin_ratio(state) do
    if state.account_value > 0 do
      (state.account_value - state.total_margin_used) / state.account_value
    else
      1.0
    end
  end
end
