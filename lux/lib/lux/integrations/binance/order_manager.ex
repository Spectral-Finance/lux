defmodule Lux.Integrations.Binance.OrderManager do
  @moduledoc """
  GenServer for managing the full order lifecycle on Binance.

  Handles placing, cancelling, modifying, and tracking orders
  across their lifecycle: NEW → PARTIALLY_FILLED → FILLED / CANCELED / EXPIRED / REJECTED.

  Maintains ETS tables for fast order lookups and state transitions.

  ## Usage

      {:ok, pid} = OrderManager.start_link(name: MyOrderManager)

      # Place a limit order
      OrderManager.place_order(pid, :spot, %{
        symbol: "ETHUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: 0.1,
        price: 2800.0,
        time_in_force: "GTC"
      })

      # Cancel an order
      OrderManager.cancel_order(pid, :spot, "ETHUSDT", 123456)

      # Get all open orders
      OrderManager.get_open_orders(pid)
  """

  use GenServer

  require Logger

  alias Lux.Integrations.Binance.Client
  alias Lux.Integrations.Binance.Models

  @type order_state :: :new | :partially_filled | :filled | :canceled | :expired | :rejected

  @doc false
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Places a new order on Binance.

  ## Parameters

    * `pid` — The OrderManager process
    * `market` — `:spot` or `:futures`
    * `params` — Order parameters (symbol, side, type, quantity, price, etc.)

  ## Returns

    * `{:ok, order}` — Order placed successfully
    * `{:error, reason}` — Order placement failed
  """
  @spec place_order(pid() | atom(), atom(), map()) :: {:ok, term()} | {:error, term()}
  def place_order(pid, market, params) do
    GenServer.call(pid, {:place_order, market, params})
  end

  @doc """
  Cancels an existing order.

  ## Parameters

    * `pid` — The OrderManager process
    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol
    * `order_id` — Order ID to cancel

  ## Returns

    * `{:ok, result}` — Order cancelled
    * `{:error, reason}` — Cancellation failed
  """
  @spec cancel_order(pid() | atom(), atom(), String.t(), integer()) :: {:ok, term()} | {:error, term()}
  def cancel_order(pid, market, symbol, order_id) do
    GenServer.call(pid, {:cancel_order, market, symbol, order_id})
  end

  @doc """
  Cancels all open orders for a symbol.

  ## Parameters

    * `pid` — The OrderManager process
    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol

  ## Returns

    * `{:ok, cancelled_count}` — Orders cancelled
    * `{:error, reason}` — Cancellation failed
  """
  @spec cancel_all_orders(pid() | atom(), atom(), String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def cancel_all_orders(pid, market, symbol) do
    GenServer.call(pid, {:cancel_all_orders, market, symbol})
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
  Syncs orders from the Binance API into the local ETS store.
  """
  @spec sync_orders(pid() | atom(), atom()) :: {:ok, non_neg_integer()} | {:error, term()}
  def sync_orders(pid, market) do
    GenServer.call(pid, {:sync_orders, market})
  end

  @doc """
  Handles a user data stream execution report event.
  """
  @spec handle_execution_report(pid() | atom(), map()) :: :ok
  def handle_execution_report(pid, event) do
    GenServer.cast(pid, {:execution_report, event})
  end

  @impl true
  def init(opts) do
    table_name = Keyword.get(opts, :ets_table, :binance_orders)
    ets = :ets.new(table_name, [:named_table, :public, :set, read_concurrency: true])

    rate_limiter = Keyword.get(opts, :rate_limiter)

    state = %{
      ets: ets,
      rate_limiter: rate_limiter
    }

    Logger.info("[BinanceOrderManager] Initialized with ETS table: #{inspect(table_name)}")

    {:ok, state}
  end

  @impl true
  def handle_call({:place_order, market, params}, _from, state) do
    client_opts = build_client_opts(state)

    result =
      case Client.place_order(market, params, client_opts) do
        {:ok, response} ->
          order = Models.parse_order(response)
          :ets.insert(state.ets, {order.order_id, order})
          Logger.info("[BinanceOrderManager] Order placed: #{order.symbol} #{order.side} #{order.type} @ #{order.price} status=#{order.status}")
          {:ok, order}

        {:error, reason} ->
          Logger.error("[BinanceOrderManager] Order placement failed: #{inspect(reason)}")
          {:error, reason}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:cancel_order, market, symbol, order_id}, _from, state) do
    client_opts = build_client_opts(state)

    result =
      case Client.cancel_order(market, symbol, order_id, client_opts) do
        {:ok, response} ->
          parsed = Models.parse_order(response)
          :ets.insert(state.ets, {order_id, parsed})
          Logger.info("[BinanceOrderManager] Order #{order_id} cancelled: #{symbol}")
          {:ok, parsed}

        {:error, reason} ->
          Logger.error("[BinanceOrderManager] Cancel order #{order_id} failed: #{inspect(reason)}")
          {:error, reason}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:cancel_all_orders, market, symbol}, _from, state) do
    client_opts = build_client_opts(state)

    result =
      case Client.cancel_all_orders(market, symbol, client_opts) do
        {:ok, responses} when is_list(responses) ->
          Enum.each(responses, fn r ->
            parsed = Models.parse_order(r)
            :ets.insert(state.ets, {parsed.order_id, parsed})
          end)

          {:reply, {:ok, length(responses)}, state}

        {:ok, _} ->
          Logger.info("[BinanceOrderManager] All orders cancelled for #{symbol}")
          {:reply, {:ok, 0}, state}

        {:error, reason} ->
          Logger.error("[BinanceOrderManager] Bulk cancel failed: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
  end

  @impl true
  def handle_call(:get_open_orders, _from, state) do
    orders =
      state.ets
      |> :ets.tab2list()
      |> Enum.map(fn {_, order} -> order end)
      |> Enum.filter(fn o -> o.status in ["NEW", "PARTIALLY_FILLED", "new", "partially_filled", "open"] end)

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
  def handle_call({:sync_orders, market}, _from, state) do
    client_opts = build_client_opts(state)
    {:ok, orders} = Client.get_open_orders(market, nil, client_opts)

    Enum.each(orders, fn raw ->
      parsed = Models.parse_order(raw)
      :ets.insert(state.ets, {parsed.order_id, parsed})
    end)

    {:reply, {:ok, length(orders)}, state}
  end

  @impl true
  def handle_cast({:execution_report, event}, state) do
    handle_execution_report_event(event, state)
    {:noreply, state}
  end

  defp handle_execution_report_event(event, state) do
    order_data = event

    order_id = order_data["i"] || order_data["orderId"]
    if order_id do
      order = Models.parse_order(order_data)
      :ets.insert(state.ets, {order.order_id, order})

      Logger.debug("[BinanceOrderManager] Execution report: #{order.order_id} #{order.symbol} -> #{order.status}")
    end
  end

  defp build_client_opts(state) do
    %{}
    |> maybe_add_rate_limiter(state.rate_limiter)
  end

  defp maybe_add_rate_limiter(opts, nil), do: opts
  defp maybe_add_rate_limiter(opts, rate_limiter), do: Map.put(opts, :rate_limiter, rate_limiter)
end
