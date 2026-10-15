defmodule Lux.Prisms.Web3.HyperliquidPrism do
  @moduledoc """
  A Prism for Hyperliquid perpetual trading, L2 orderbook inspection, leverage & margin
  management, order execution (market, limit, trigger, TWAP), and liquidation risk protection.

  Supported actions:
  - `"list_markets"`: Lists Hyperliquid perpetual market metadata and funding rates
  - `"get_orderbook"`: Retrieves L2 bid/ask depth and spread for a perpetual asset
  - `"set_leverage"`: Configures per-asset leverage and cross/isolated margin mode
  - `"update_isolated_margin"`: Adds or removes isolated margin collateral for an open position
  - `"place_order"`: Places a market, limit, trigger (SL/TP), or TWAP perpetual order
  - `"cancel_order"`: Cancels a resting open order by `order_id`
  - `"list_open_orders"`: Lists open resting orders for a trader wallet
  - `"get_user_state"`: Returns positions, unrealized/realized PnL, ROE%, and liquidation prices
  - `"assess_risk"`: Evaluates liquidation distance and optionally executes auto-deleveraging
  """

  use Lux.Prism,
    name: "Hyperliquid Perpetual Trading Prism",
    description:
      "Executes Hyperliquid perpetual orders, manages leverage/margin, and protects against liquidation",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Hyperliquid operation to execute"
        },
        wallet: %{
          type: :string,
          description: "Trader Ethereum address"
        },
        coin: %{
          type: :string,
          description: "Perpetual asset symbol (e.g. BTC, ETH, SOL, HYPE)"
        },
        side: %{
          type: :string,
          description: "Order side (buy or sell)"
        },
        size: %{
          type: :number,
          description: "Order size in base asset units"
        },
        order_type: %{
          type: :string,
          description: "Order type (market, limit, trigger, twap)"
        },
        price: %{
          type: :number,
          description: "Limit execution price"
        },
        trigger_price: %{
          type: :number,
          description: "Stop-loss or take-profit trigger price"
        },
        leverage: %{
          type: :integer,
          description: "Target leverage multiplier"
        },
        margin_mode: %{
          type: :string,
          description: "Margin mode (cross or isolated)"
        },
        order_id: %{
          type: :string,
          description: "Order identifier for cancellation"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        data: %{type: :object}
      },
      required: ["status"]
    }

  alias Lux.Web3.Exchanges.Hyperliquid

  @doc """
  Executes the requested Hyperliquid perpetual trading action.
  """
  def handler(input, _ctx) do
    action = fetch_param(input, :action)
    dispatch(action, input)
  end

  defp dispatch("list_markets", _input) do
    {:ok, markets} = Hyperliquid.list_markets()
    {:ok, %{status: "ok", data: %{markets: markets}}}
  end

  defp dispatch("get_orderbook", input) do
    coin = fetch_param(input, :coin, "BTC")
    levels = fetch_param(input, :levels, 5)

    case Hyperliquid.get_l2_orderbook(coin, levels: levels) do
      {:ok, book} -> {:ok, %{status: "ok", data: book}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("set_leverage", input) do
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000082")
    coin = fetch_param(input, :coin, "BTC")
    leverage = fetch_param(input, :leverage, 10)
    mode = normalize_margin_mode(fetch_param(input, :margin_mode, "cross"))

    case Hyperliquid.set_leverage(wallet, coin, leverage, mode) do
      {:ok, res} -> {:ok, %{status: "ok", data: res}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("update_isolated_margin", input) do
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000082")
    coin = fetch_param(input, :coin, "BTC")
    delta = fetch_param(input, :delta_usdc, 0.0)

    case Hyperliquid.update_isolated_margin(wallet, coin, delta) do
      {:ok, pos} -> {:ok, %{status: "ok", data: pos}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("place_order", input) do
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000082")

    case Hyperliquid.place_order(wallet, input) do
      {:ok, order} -> {:ok, %{status: "ok", data: order}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("cancel_order", input) do
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000082")
    order_id = fetch_param(input, :order_id, "")

    case Hyperliquid.cancel_order(wallet, order_id) do
      {:ok, canceled} -> {:ok, %{status: "ok", data: canceled}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("list_open_orders", input) do
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000082")
    coin = fetch_param(input, :coin)
    opts = if is_binary(coin), do: [coin: coin], else: []
    {:ok, orders} = Hyperliquid.list_open_orders(wallet, opts)
    {:ok, %{status: "ok", data: %{orders: orders}}}
  end

  defp dispatch("get_user_state", input) do
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000082")
    {:ok, state} = Hyperliquid.get_user_state(wallet)
    {:ok, %{status: "ok", data: state}}
  end

  defp dispatch("assess_risk", input) do
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000082")
    auto_protect = fetch_param(input, :auto_protect, false)
    {:ok, report} = Hyperliquid.assess_risk_and_protect(wallet, auto_protect: auto_protect)
    {:ok, %{status: "ok", data: report}}
  end

  defp dispatch(_unknown, _input), do: {:error, :unsupported_action}

  defp fetch_param(map, key, default \\ nil) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp normalize_margin_mode(m) when m in [:isolated, "isolated"], do: :isolated
  defp normalize_margin_mode(_), do: :cross
end
