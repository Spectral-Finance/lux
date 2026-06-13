 ```diff
--- /dev/null
+++ b/lux/lib/lux/exchanges/hyperliquid.ex
@@ -0,0 +1,268 @@
+defmodule Lux.Exchanges.Hyperliquid do
+  @moduledoc """
+  Hyperliquid exchange integration for perpetual trading.
+  Provides position management, leverage control, risk monitoring,
+  order execution, liquidation protection, PnL tracking, and margin management.
+  """
+
+  alias Lux.Exchanges.Hyperliquid.{
+    Client,
+    Order,
+    Position,
+    Risk,
+    Margin,
+    Liquidation
+  }
+
+  @type order_type :: :market | :limit | :stop | :stop_limit
+  @type side :: :buy | :sell
+  @type order_status :: :pending | :open | :filled | :partially_filled | :cancelled | :rejected
+
+  # API Configuration
+  @api_url "https://api.hyperliquid.xyz"
+  @testnet_url "https://api.hyperliquid-testnet.xyz"
+
+  @doc """
+  Returns the base API URL based on environment configuration.
+  """
+  def base_url do
+    if Application.get_env(:lux, :hyperliquid_testnet, false) do
+      @testnet_url
+    else
+      @api_url
+    end
+  end
+
+  @doc """
+  Places a new order on Hyperliquid.
+
+  ## Options
+    - `:symbol` - Trading pair (e.g., "BTC-PERP")
+    - `:side` - :buy or :sell
+    - `:order_type` - :market, :limit, :stop, :stop_limit
+    - `:size` - Order size
+    - `:price` - Limit price (required for limit orders)
+    - `:leverage` - Leverage multiplier (default: 1)
+    - `:stop_price` - Stop price (required for stop orders)
+    - `:time_in_force` - :gtc, :ioc, :fok (default: :gtc)
+    - `:reduce_only` - Whether order only reduces position (default: false)
+    - `:post_only` - Whether order is post-only (default: false)
+
+  ## Examples
+
+      iex> Hyperliquid.place_order(
+      ...>   symbol: "BTC-PERP",
+      ...>   side: :buy,
+      ...>   order_type: :limit,
+      ...>   size: 0.5,
+      ...>   price: 50000.0,
+      ...>   leverage: 5
+      ...> )
+      {:ok, %Order{...}}
+  """
+  def place_order(opts) do
+    Order.place(opts)
+  end
+
+  @doc """
+  Cancels an existing order.
+  """
+  def cancel_order(order_id, opts \\ []) do
+    Order.cancel(order_id, opts)
+  end
+
+  @doc """
+  Modifies an existing order.
+  """
+  def modify_order(order_id, updates, opts \\ []) do
+    Order.modify(order_id, updates, opts)
+  end
+
+  @doc """
+  Gets all open orders.
+  """
+  def list_open_orders(opts \\ []) do
+    Order.list_open(opts)
+  end
+
+  @doc """
+  Gets order details by ID.
+  """
+  def get_order(order_id, opts \\ []) do
+    Order.get(order_id, opts)
+  end
+
+  # Position Management
+
+  @doc """
+  Gets current positions for the account.
+  """
+  def get_positions(opts \\ []) do
+    Position.list(opts)
+  end
+
+  @doc """
+  Gets details for a specific position.
+  """
+  def get_position(symbol, opts \\ []) do
+    Position.get(symbol, opts)
+  end
+
+  @doc """
+  Closes a position by symbol.
+  """
+  def close_position(symbol, opts \\ []) do
+    Position.close(symbol, opts)
+  end
+
+  @doc """
+  Sets leverage for a specific symbol.
+  """
+  def set_leverage(symbol, leverage, opts \\ []) do
+    Position.set_leverage(symbol, leverage, opts)
+  end
+
+  # Risk Management
+
+  @doc """
+  Gets current risk metrics for the account.
+  """
+  def get_risk_metrics(opts \\ []) do
+    Risk.get_metrics(opts)
+  end
+
+  @doc """
+  Sets risk limits for the account.
+  """
+  def set_risk_limits(limits, opts \\ []) do
+    Risk.set_limits(limits, opts)
+  end
+
+  @doc """
+  Checks if an order would violate risk limits.
+  """
+  def check_risk(order_params, opts \\ []) do
+    Risk.check_order(order_params, opts)
+  end
+
+  # Margin Management
+
+  @doc """
+  Gets margin information for the account.
+  """
+  def get_margin_info(opts \\ []) do
+    Margin.get_info(opts)
+  end
+
+  @doc """
+  Adds margin to a position.
+  """
+  def add_margin(symbol, amount, opts \\ []) do
+    Margin.add(symbol, amount, opts)
+  end
+
+  @doc """
+  Removes margin from a position.
+  """
+  def remove_margin(symbol, amount, opts \\ []) do
+    Margin.remove(symbol, amount, opts)
+  end
+
+  # Liquidation Monitoring
+
+  @doc """
+  Gets liquidation risk information.
+  """
+  def get_liquidation_risk(opts \\ []) do
+    Liquidation.get_risk(opts)
+  end
+
+  @doc """
+  Gets estimated liquidation price for a position.
+  """
+  def get_liquidation_price(symbol, opts \\ []) do
+    Liquidation.get_price(symbol, opts)
+  end
+
+  @doc """
+  Subscribes to liquidation alerts.
+  """
+  def subscribe_liquidation_alerts(callback, opts \\ []) do
+    Liquidation.subscribe_alerts(callback, opts)
+  end
+
+  # PnL Tracking
+
+  @doc """
+  Gets realized and unrealized PnL.
+  """
+  def get_pnl(opts \\ []) do
+    Position.get_pnl(opts)
+  end
+
+  @doc """
+  Gets PnL history for a time period.
+  """
+  def get_pnl_history(start_time, end_time, opts \\ []) do
+    Position.get_pnl_history(start_time