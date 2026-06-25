defmodule Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism do
  @moduledoc """
  A prism that executes orders on the Hyperliquid exchange.

  ## Example

      # Limit order
      iex> Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism.run(%{
      ...>   coin: "ETH",
      ...>   is_buy: true,
      ...>   sz: 0.0051,
      ...>   limit_px: 2800.0,
      ...>   order_type: %{limit: %{tif: "Gtc"}},
      ...>   reduce_only: false,
      ...>   vault_address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok,
       %{
         "status" => "success",
         "order_result" => %{
           # ... response from Hyperliquid
         }
       }}

      # Trigger order (Stop Loss)
      iex> Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism.run(%{
      ...>   coin: "ETH",
      ...>   is_buy: false,
      ...>   sz: 0.1,
      ...>   limit_px: 2800.0,
      ...>   order_type: %{
      ...>     trigger: %{
      ...>       triggerPx: 2900.0,
      ...>       isMarket: true,
      ...>       tpsl: "sl"
      ...>     }
      ...>   },
      ...>   reduce_only: true
      ...> })

      # Slippage-controlled order (market-like with price protection)
      iex> Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism.run(%{
      ...>   coin: "ETH",
      ...>   is_buy: true,
      ...>   sz: 0.1,
      ...>   limit_px: 2800.0,
      ...>   order_type: %{slippage: 0.5},
      ...>   reduce_only: false
      ...> })
      {:ok, %{
        "status" => "success",
        "order_type" => "slippage_controlled",
        "effective_px" => 2814.0,
        "slippage_pct" => 0.5,
        "order_result" => %{...}
      }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid Order Execution",
    description: "Executes orders on Hyperliquid exchange",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        is_buy: %{
          type: :boolean,
          description: "True for buy orders, false for sell orders"
        },
        sz: %{
          type: :number,
          description: "Order size in base currency"
        },
        limit_px: %{
          type: :number,
          description: "Limit price for the order"
        },
        order_type: %{
          type: :object,
          description: "Order type configuration",
          oneOf: [
            # Limit order type
            %{
              type: :object,
              properties: %{
                limit: %{
                  type: :object,
                  properties: %{
                    tif: %{
                      type: :string,
                      description:
                        "Time in force: Alo (Allow Limit Only), Ioc (Immediate or Cancel), Gtc (Good Till Cancel)",
                      enum: ["Alo", "Ioc", "Gtc"]
                    }
                  },
                  required: ["tif"]
                }
              },
              required: ["limit"]
            },
            # Trigger order type
            %{
              type: :object,
              properties: %{
                trigger: %{
                  type: :object,
                  properties: %{
                    triggerPx: %{
                      type: :number,
                      description: "Price at which the trigger order activates"
                    },
                    isMarket: %{
                      type: :boolean,
                      description: "Whether to execute as market order when triggered"
                    },
                    tpsl: %{
                      type: :string,
                      description: "Take profit (tp) or stop loss (sl)",
                      enum: ["tp", "sl"]
                    }
                  },
                  required: ["triggerPx", "isMarket", "tpsl"]
                }
              },
              required: ["trigger"]
            },
            # Slippage order type (for market-like execution with slippage control)
            %{
              type: :object,
              properties: %{
                slippage: %{
                  type: :number,
                  description: "Maximum slippage percentage (e.g., 0.5 for 0.5%)"
                }
              },
              required: ["slippage"]
            }
          ]
        },
        reduce_only: %{
          type: :boolean,
          description: "Whether the order should only reduce position",
          default: false
        },
        vault_address: %{
          type: :string,
          description: "Optional vault address for executing orders",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        tp_limit: %{
          type: :object,
          description: "Take-profit limit order configuration",
          properties: %{
            limit_px: %{type: :number},
            sz: %{type: :number}
          }
        },
        sl_limit: %{
          type: :object,
          description: "Stop-loss limit order configuration",
          properties: %{
            limit_px: %{type: :number},
            sz: %{type: :number}
          }
        }
      },
      required: ["coin", "is_buy", "sz", "limit_px", "order_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        order_result: %{type: :object, description: "Raw response from Hyperliquid API"}
      },
      required: ["status", "order_result"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- {:ok, Config.hyperliquid_account_address()},
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- execute_order(private_key, address, api_url, input) do
      {:ok, %{status: "success", order_result: result}}
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

  defp execute_order(private_key, address, api_url, params) do
    python_result =
      python variables: %{
               private_key: private_key,
               address: address,
               api_url: api_url,
               params: params
             } do
        ~PY"""
        from hyperliquid.exchange import Exchange
        from hyperliquid_utils.setup import setup

        address, info, exchange = setup(private_key, address, api_url, skip_ws=True)

        # Update exchange instance if vault_address is provided
        if "vault_address" in params and params["vault_address"]:
            exchange = Exchange(
                exchange.wallet,
                exchange.base_url,
                vault_address=params["vault_address"]
            )

        coin = params["coin"]
        is_buy = params["is_buy"]
        sz = params["sz"]
        limit_px = params["limit_px"]
        order_type = params["order_type"]
        reduce_only = params.get("reduce_only", False)

        # Handle slippage order type (approximate market order with slippage control)
        if "slippage" in order_type:
            # Get current mid price
            meta_and_ctx = info.meta_and_asset_ctxs()
            meta = meta_and_ctx[0]
            ctx = meta_and_ctx[1]
            universe = meta["universe"]
            mid_px = None
            for token in universe:
                if token["name"] == coin:
                    asset_idx = token["assetIndex"]
                    if asset_idx < len(ctx):
                        mid_px = float(ctx[asset_idx]["midPx"])
                        break

            if mid_px is None:
                return {"error": f"Could not get price for {coin}"}

            slippage_pct = order_type["slippage"] / 100.0
            if is_buy:
                # For buys, set limit price above mid to ensure execution
                effective_px = mid_px * (1 + slippage_pct)
            else:
                # For sells, set limit price below mid
                effective_px = mid_px * (1 - slippage_pct)

            order_result = exchange.order(
                name=coin,
                is_buy=is_buy,
                sz=sz,
                limit_px=effective_px,
                order_type={"limit": {"tif": "Gtc"}},
                reduce_only=reduce_only
            )

            result = {
                "status": "success",
                "order_type": "slippage_controlled",
                "requested_limit_px": limit_px,
                "effective_px": effective_px,
                "slippage_pct": order_type["slippage"],
                "order_result": order_result
            }
        else:
            order_result = exchange.order(
                name=coin,
                is_buy=is_buy,
                sz=sz,
                limit_px=limit_px,
                order_type=order_type,
                reduce_only=reduce_only
            )
            result = order_result

        # Attach take-profit and stop-loss limit orders if provided
        if "tp_limit" in params and params["tp_limit"]:
            tp = params["tp_limit"]
            try:
                tp_result = exchange.order(
                    name=coin,
                    is_buy=not is_buy,
                    sz=tp.get("sz", sz),
                    limit_px=tp["limit_px"],
                    order_type={"limit": {"tif": "Gtc"}},
                    reduce_only=True
                )
                if isinstance(result, dict):
                    result["tp_limit_result"] = tp_result
            except Exception:
                if isinstance(result, dict):
                    result["tp_limit_error"] = "Failed to place TP order"

        if "sl_limit" in params and params["sl_limit"]:
            sl = params["sl_limit"]
            try:
                sl_result = exchange.order(
                    name=coin,
                    is_buy=not is_buy,
                    sz=sl.get("sz", sz),
                    limit_px=sl["limit_px"],
                    order_type={"limit": {"tif": "Gtc"}},
                    reduce_only=True
                )
                if isinstance(result, dict):
                    result["sl_limit_result"] = sl_result
            except Exception:
                if isinstance(result, dict):
                    result["sl_limit_error"] = "Failed to place SL order"

        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
