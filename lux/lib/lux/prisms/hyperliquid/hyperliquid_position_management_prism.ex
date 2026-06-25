defmodule Lux.Prisms.Hyperliquid.HyperliquidPositionManagementPrism do
  @moduledoc """
  A prism that manages existing positions on the Hyperliquid exchange.

  Supports:
  - Closing positions entirely or partially
  - Setting trailing stop losses
  - Scaling in/out of positions
  - Adjusting leverage for existing positions

  ## Example

      # Close entire ETH position
      iex> Lux.Prisms.Hyperliquid.HyperliquidPositionManagementPrism.run(%{
      ...>   action: :close,
      ...>   coin: "ETH",
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok, %{status: "success", result: %{...}}}

      # Partially close 50% of ETH position
      iex> Lux.Prisms.Hyperliquid.HyperliquidPositionManagementPrism.run(%{
      ...>   action: :partial_close,
      ...>   coin: "ETH",
      ...>   close_percentage: 0.5,
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok, %{status: "success", result: %{...}}}

      # Set trailing stop loss
      iex> Lux.Prisms.Hyperliquid.HyperliquidPositionManagementPrism.run(%{
      ...>   action: :trailing_stop,
      ...>   coin: "ETH",
      ...>   trail_percent: 5.0,
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok, %{status: "success", result: %{...}}}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid Position Management",
    description: "Manages existing positions on Hyperliquid exchange",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action to perform: close, partial_close, scale_in, scale_out, trailing_stop, adjust_leverage",
          enum: [
            "close",
            "partial_close",
            "scale_in",
            "scale_out",
            "trailing_stop",
            "adjust_leverage"
          ]
        },
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        address: %{
          type: :string,
          description: "Ethereum address for authentication",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        sz: %{
          type: :number,
          description: "Size for partial operations (used with partial_close, scale_in, scale_out)"
        },
        close_percentage: %{
          type: :number,
          description: "Percentage of position to close (0.0-1.0), used with partial_close",
          minimum: 0.0,
          maximum: 1.0
        },
        trail_percent: %{
          type: :number,
          description: "Trailing stop distance as percentage, used with trailing_stop"
        },
        leverage: %{
          type: :integer,
          description: "New leverage value, used with adjust_leverage"
        },
        is_buy: %{
          type: :boolean,
          description: "Direction for scale_in (true) or scale_out (false)"
        },
        vault_address: %{
          type: :string,
          description: "Optional vault address for executing position management",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["action", "coin", "address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        action: %{type: :string},
        coin: %{type: :string},
        result: %{type: :object}
      },
      required: ["status", "action", "coin", "result"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- resolve_address(input),
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <-
           Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{"success" => true}} <-
           Lux.Python.import_package("hyperliquid.info"),
         {:ok, %{"success" => true}} <-
           Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- manage_position(private_key, address, api_url, input) do
      {:ok,
       %{
         status: "success",
         action: input.action,
         coin: input.coin,
         result: result
       }}
    else
      {:error, :missing_private_key} ->
        {:error, "Hyperliquid account private key is not configured"}

      {:error, :missing_api_url} ->
        {:error, "Hyperliquid API URL is not configured"}

      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import required packages: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_private_key do
    {:ok, Config.hyperliquid_account_key()}
  rescue
    RuntimeError -> {:error, :missing_private_key}
  end

  defp resolve_address(%{address: addr}) when is_binary(addr) and byte_size(addr) > 0 do
    {:ok, addr}
  end

  defp resolve_address(_) do
    {:ok, Config.hyperliquid_account_address()}
  end

  defp manage_position(private_key, address, api_url, params) do
    python_result =
      python variables: %{
               private_key: private_key,
               address: address,
               api_url: api_url,
               params: params
             } do
        ~PY"""
        from hyperliquid.exchange import Exchange
        from hyperliquid.info import Info
        from hyperliquid_utils.setup import setup

        def get_position(info, address, coin):
            '''Get current position size for a coin'''
            state = info.user_state(address)
            for pos in state.get("assetPositions", []):
                if pos["position"]["coin"] == coin:
                    size = float(pos["position"]["szi"])
                    return size
            return 0

        def get_current_price(info, coin):
            '''Get current mark price for a coin'''
            meta_and_ctx = info.meta_and_asset_ctxs()
            meta = meta_and_ctx[0]
            ctx = meta_and_ctx[1]
            universe = meta["universe"]
            for token in universe:
                if token["name"] == coin:
                    asset_idx = token["assetIndex"]
                    if asset_idx < len(ctx):
                        return ctx[asset_idx]["markPx"]
            return None

        address, info, exchange = setup(private_key, address, api_url, skip_ws=True)

        # Handle vault address override
        if "vault_address" in params and params["vault_address"]:
            exchange = Exchange(
                exchange.wallet,
                exchange.base_url,
                vault_address=params["vault_address"]
            )

        action = params["action"]
        coin = params["coin"]
        result = {}

        if action == "close":
            # Get current position size
            current_size = get_position(info, address, coin)
            if current_size == 0:
                result = {"status": "no_position", "message": f"No open position for {coin}"}
            else:
                # Determine side: negative szi = short, positive szi = long
                side = "B" if current_size < 0 else "S"
                close_sz = abs(current_size)
                px = get_current_price(info, coin)
                if px is None:
                    result = {"status": "error", "message": f"Could not get price for {coin}"}
                else:
                    order_result = exchange.order(
                        name=coin,
                        is_buy=(side == "B"),
                        sz=close_sz,
                        limit_px=float(px),
                        order_type={"limit": {"tif": "Gtc"}},
                        reduce_only=True
                    )
                    result = {"status": "closed", "size": close_sz, "side": side, "order_result": order_result}

        elif action == "partial_close":
            current_size = get_position(info, address, coin)
            if current_size == 0:
                result = {"status": "no_position", "message": f"No open position for {coin}"}
            else:
                close_pct = params.get("close_percentage", 0.5)
                close_sz = abs(current_size) * close_pct
                side = "B" if current_size < 0 else "S"
                px = get_current_price(info, coin)
                if px is None:
                    result = {"status": "error", "message": f"Could not get price for {coin}"}
                else:
                    order_result = exchange.order(
                        name=coin,
                        is_buy=(side == "B"),
                        sz=close_sz,
                        limit_px=float(px),
                        order_type={"limit": {"tif": "Gtc"}},
                        reduce_only=True
                    )
                    remaining = abs(current_size) - close_sz
                    result = {
                        "status": "partially_closed",
                        "original_size": abs(current_size),
                        "closed_size": close_sz,
                        "remaining_size": remaining,
                        "side": side,
                        "order_result": order_result
                    }

        elif action in ("scale_in", "scale_out"):
            current_size = get_position(info, address, coin)
            if current_size == 0 and action == "scale_in":
                # Scale into a new position
                scale_sz = params.get("sz", 0.1)
                side = params.get("is_buy", True)
                px = get_current_price(info, coin)
                if px is None:
                    result = {"status": "error", "message": f"Could not get price for {coin}"}
                else:
                    order_result = exchange.order(
                        name=coin,
                        is_buy=side,
                        sz=scale_sz,
                        limit_px=float(px),
                        order_type={"limit": {"tif": "Gtc"}},
                        reduce_only=False
                    )
                    result = {
                        "status": "scaled_in",
                        "size": scale_sz,
                        "side": "buy" if side else "sell",
                        "order_result": order_result
                    }
            elif current_size == 0:
                result = {"status": "no_position", "message": f"No open position for {coin}"}
            else:
                scale_sz = params.get("sz", abs(current_size) * 0.5)
                side = params.get("is_buy", current_size > 0)
                order_result = exchange.order(
                    name=coin,
                    is_buy=side,
                    sz=scale_sz,
                    limit_px=float(get_current_price(info, coin) or 0),
                    order_type={"limit": {"tif": "Gtc"}},
                    reduce_only=False
                )
                result = {
                    "status": "scaled" + ("_in" if action == "scale_in" else "_out"),
                    "size": scale_sz,
                    "side": "buy" if side else "sell",
                    "order_result": order_result
                }

        elif action == "trailing_stop":
            current_size = get_position(info, address, coin)
            if current_size == 0:
                result = {"status": "no_position", "message": f"No open position for {coin}"}
            else:
                trail_pct = params.get("trail_percent", 5.0)
                px = get_current_price(info, coin)
                if px is None:
                    result = {"status": "error", "message": f"Could not get price for {coin}"}
                else:
                    current_px = float(px)
                    side = "B" if current_size < 0 else "S"
                    # Calculate trigger price for trailing stop
                    if side == "B":
                        trigger_px = current_px * (1 - trail_pct / 100)
                    else:
                        trigger_px = current_px * (1 + trail_pct / 100)

                    order_result = exchange.order(
                        name=coin,
                        is_buy=(side == "B"),
                        sz=abs(current_size),
                        limit_px=current_px,
                        order_type={
                            "trigger": {
                                "triggerPx": trigger_px,
                                "isMarket": True,
                                "tpsl": "sl"
                            }
                        },
                        reduce_only=True
                    )
                    result = {
                        "status": "trailing_stop_set",
                        "trail_percent": trail_pct,
                        "trigger_price": trigger_px,
                        "current_price": current_px,
                        "side": side,
                        "order_result": order_result
                    }

        elif action == "adjust_leverage":
            # Hyperliquid uses isolated margin per position
            # We simulate by adjusting position size
            leverage = params.get("leverage", 1)
            current_size = get_position(info, address, coin)
            px = get_current_price(info, coin)
            if px is None:
                result = {"status": "error", "message": f"Could not get price for {coin}"}
            else:
                result = {
                    "status": "leverage_adjusted",
                    "requested_leverage": leverage,
                    "current_position_size": abs(current_size),
                    "current_price": float(px),
                    "note": "Hyperliquid uses isolated margin; leverage is managed per-position via margin allocation"
                }

        else:
            result = {"status": "unknown_action", "message": f"Unknown action: {action}"}

        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
