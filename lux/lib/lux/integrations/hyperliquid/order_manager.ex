defmodule Lux.Integrations.Hyperliquid.OrderManager do
  @moduledoc """
  GenServer for managing the full order lifecycle on Hyperliquid.

  Handles placing, cancelling, modifying, and tracking orders
  across their lifecycle: PENDING → OPEN → PARTIAL_FILL → FILLED / CANCELLED.

  Maintains ETS tables for fast order lookups and state transitions.

  ## Usage

      {:ok, pid} = OrderManager.start_link(name: MyOrderManager)

      # Place a limit order
      OrderManager.place_order(pid, %{
        asset: "ETH",
        is_buy: true,
        size: 0.1,
        price: 2800.0,
        order_type: %{limit: %{tif: "Gtc"}}
      })

      # Cancel an order
      OrderManager.cancel_order(pid, "ETH", 123456)

      # Get all open orders
      OrderManager.get_open_orders(pid)
  """

  use GenServer

  require Logger

  alias Lux.Config
  alias Lux.Integrations.Hyperliquid.Client
  alias Lux.Integrations.Hyperliquid.Models

  @type order_state :: :pending | :open | :partial_fill | :filled | :cancelled | :rejected

  @doc false
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Places a new order on Hyperliquid.

  ## Parameters

    * `pid` — The OrderManager process
    * `params` — Order parameters (asset, is_buy, size, price, order_type, reduce_only)

  ## Returns

    * `{:ok, order_result}` — Order placed successfully
    * `{:error, reason}` — Order placement failed
  """
  @spec place_order(pid() | atom(), map()) :: {:ok, term()} | {:error, term()}
  def place_order(pid, params) do
    GenServer.call(pid, {:place_order, params})
  end

  @doc """
  Cancels an existing order.

  ## Parameters

    * `pid` — The OrderManager process
    * `asset` — Trading pair
    * `order_id` — Order ID to cancel

  ## Returns

    * `{:ok, result}` — Order cancelled
    * `{:error, reason}` — Cancellation failed
  """
  @spec cancel_order(pid() | atom(), String.t(), integer()) :: {:ok, term()} | {:error, term()}
  def cancel_order(pid, asset, order_id) do
    GenServer.call(pid, {:cancel_order, asset, order_id})
  end

  @doc """
  Cancels all open orders.

  ## Parameters

    * `pid` — The OrderManager process

  ## Returns

    * `{:ok, cancelled_count}` — Orders cancelled
    * `{:error, reason}` — Cancellation failed
  """
  @spec cancel_all_orders(pid() | atom()) :: {:ok, non_neg_integer()} | {:error, term()}
  def cancel_all_orders(pid) do
    GenServer.call(pid, :cancel_all_orders)
  end

  @doc """
  Returns all currently tracked open orders.
  """
  @spec get_open_orders(pid() | atom()) :: [Models.Order.t()]
  def get_open_orders(pid) do
    GenServer.call(pid, :get_open_orders)
  end

  @doc """
  Returns the order state for a specific order ID.
  """
  @spec get_order_state(pid() | atom(), integer()) :: {:ok, Models.Order.t()} | {:error, :not_found}
  def get_order_state(pid, order_id) do
    GenServer.call(pid, {:get_order_state, order_id})
  end

  @doc """
  Updates an order's state based on a WebSocket event (fill, cancel, etc.).
  """
  @spec handle_order_update(pid() | atom(), map()) :: :ok
  def handle_order_update(pid, event) do
    GenServer.cast(pid, {:order_update, event})
  end

  @impl true
  def init(opts) do
    table_name = Keyword.get(opts, :ets_table)
    ets_opts = if table_name do
      [:named_table, :public, :set, read_concurrency: true]
    else
      [:public, :set, read_concurrency: true]
    end
    ets = :ets.new(table_name || :hyperliquid_orders, ets_opts)

    state = %{
      ets: ets,
      address: Config.hyperliquid_account_address()
    }

    Logger.info("[OrderManager] Initialized with ETS table: #{inspect(ets)}")

    {:ok, state}
  end

  @impl true
  def handle_call({:place_order, params}, _from, state) do
    result =
      case Client.place_order(params) do
        {:ok, response} ->
          order = build_order_record(params, response)
          :ets.insert(state.ets, {order.order_id, order})
          Logger.info("[OrderManager] Order placed: #{inspect(order)}")
          {:ok, order}

        {:error, reason} ->
          Logger.error("[OrderManager] Order placement failed: #{inspect(reason)}")
          {:error, reason}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:cancel_order, asset, order_id}, _from, state) do
    result =
      case Client.cancel_order(asset, order_id) do
        {:ok, response} ->
          mark_order_cancelled(state.ets, order_id)
          Logger.info("[OrderManager] Order #{order_id} cancelled")
          {:ok, response}

        {:error, reason} ->
          Logger.error("[OrderManager] Cancel order #{order_id} failed: #{inspect(reason)}")
          {:error, reason}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:cancel_all_orders, _from, state) do
    orders = get_all_orders(state.ets)

    cancels =
      orders
      |> Enum.filter(fn o -> o.status in ["open", "pending"] end)
      |> Enum.map(fn o -> %{asset: o.asset, order_id: o.order_id} end)

    case Client.cancel_orders(cancels) do
      {:ok, _} ->
        Enum.each(cancels, fn c -> mark_order_cancelled(state.ets, c.order_id) end)
        Logger.info("[OrderManager] Cancelled #{length(cancels)} orders")
        {:reply, {:ok, length(cancels)}, state}

      {:error, reason} ->
        Logger.error("[OrderManager] Bulk cancel failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_open_orders, _from, state) do
    orders =
      state.ets
      |> :ets.tab2list()
      |> Enum.map(fn {_, order} -> order end)
      |> Enum.filter(fn o -> o.status in ["open", "pending", "partial_fill"] end)

    {:reply, orders, state}
  end

  @impl true
  def handle_call({:get_order_state, order_id}, _from, state) do
    case :ets.lookup(state.ets, order_id) do
      [{^order_id, order}] -> {:reply, {:ok, order}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_cast({:order_update, event}, state) do
    try do
      handle_ws_event(event, state)
    rescue
      e ->
        Logger.error("[OrderManager] WS event handler crashed: #{Exception.message(e)}")
    catch
      kind, reason ->
        Logger.error("[OrderManager] WS event handler threw #{kind}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  defp build_order_record(params, response) do
    order_data = response["resting"] || response

    %Models.Order{
      order_id: order_data["oid"] || response["oid"],
      asset: params[:asset],
      is_buy: params[:is_buy],
      size: params[:size],
      price: params[:price],
      limit_px: params[:price],
      reduce_only: params[:reduce_only] || false,
      order_type: params[:order_type],
      status: order_data["status"] || "open",
      filled_size: "0",
      avg_fill_price: nil,
      timestamp: System.system_time(:millisecond),
      hash: nil,
      error: nil
    }
  end

  defp mark_order_cancelled(ets, order_id) do
    case :ets.lookup(ets, order_id) do
      [{^order_id, order}] ->
        :ets.insert(ets, {order_id, %{order | status: "cancelled"}})

      [] ->
        :ok
    end
  end

  defp get_all_orders(ets) do
    :ets.tab2list(ets) |> Enum.map(fn {_, order} -> order end)
  end

  defp handle_ws_event(%{"channel" => "orderUpdates"} = event, state) do
    order_data = event["data"]

    if order_data do
      order = Models.parse_order(order_data)
      :ets.insert(state.ets, {order.order_id, order})

      Logger.debug("[OrderManager] Order updated via WS: #{order.order_id} -> #{order.status}")
    end
  end

  defp handle_ws_event(%{"channel" => "user"} = event, state) do
    data = event["data"]

    if is_map(data) do
      fills = data["fills"] || []

      Enum.each(fills, fn fill ->
        order_id = fill["oid"]

        case :ets.lookup(state.ets, order_id) do
          [{^order_id, order}] ->
            updated = %{
              order
              | filled_size: fill["totalSz"] || order.filled_size,
                avg_fill_price: fill["avgPx"] || order.avg_fill_price,
                status: if(fill["totalSz"] == order.size, do: "filled", else: "partial_fill")
            }

            :ets.insert(state.ets, {order_id, updated})

          [] ->
            Logger.debug("[OrderManager] Received fill for unknown order: #{order_id}")
        end
      end)
    else
      Logger.debug("[OrderManager] Received user WS event with malformed data: #{inspect(event)}")
    end
  end

  defp handle_ws_event(_event, _state), do: :ok
end
