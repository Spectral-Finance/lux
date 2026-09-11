defmodule Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism do
  @moduledoc """
  A prism that executes orders on the Hyperliquid exchange with position management,
  leverage control, risk monitoring, and liquidation protection.

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

      # Order with leverage control and risk checks
      iex> Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism.run(%{
      ...>   coin: "ETH",
      ...>   is_buy: true,
      ...>   sz: 0.1,
      ...>   limit_px: 2800.0,
      ...>   order_type: %{limit: %{tif: "Gtc"}},
      ...>   leverage: 5,
      ...>   is_cross: true,
      ...>   max_position_size_ratio: 0.25,
      ...>   max_leverage: 10,
      ...>   min_liquidation_distance: 0.15
      ...> })

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address

  ## Risk Controls

  The prism supports optional risk controls that are enforced before order execution:
  - `leverage` / `is_cross` - Set leverage and margin mode before placing the order
  - `max_position_size_ratio` - Reject order if resulting position exceeds this fraction of account value
  - `max_leverage` - Reject order if resulting leverage exceeds this value
  - `min_liquidation_distance` - Reject order if liquidation price is closer than this fraction to mark price
  - `skip_risk_checks` - Bypass risk checks (defaults to false)
  """

  use Lux.Prism,
    name: "Hyperliquid Order Execution",
    description: "Executes orders on Hyperliquid exchange with position and risk management",
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
        leverage: %{
          type: :integer,
          description: "Optional leverage to set before placing the order",
          minimum: 1,
          maximum: 100
        },
        is_cross: %{
          type: :boolean,
          description: "Whether to use cross margin (true) or isolated margin (false)",
          default: true
        },
        max_position_size_ratio: %{
          type: :number,
          description:
            "Maximum allowed position value as a fraction of account value (e.g., 0.25 for 25%)",
          minimum: 0,
          maximum: 1
        },
        max_leverage: %{
          type: :number,
          description: "Maximum allowed resulting account leverage",
          minimum: 0
        },
        min_liquidation_distance: %{
          type: :number,
          description:
            "Minimum allowed distance between mark price and liquidation price as a fraction",
          minimum: 0,
          maximum: 1
        },
        skip_risk_checks: %{
          type: :boolean,
          description: "Skip pre-trade risk checks",
          default: false
        }
      },
      required: ["coin", "is_buy", "sz", "limit_px", "order_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        order_result: %{type: :object, description: "Raw response from Hyperliquid API"},
        risk_assessment: %{
          type: :object,
          description: "Risk metrics computed before order execution",
          properties: %{
            position_size_ratio: %{type: :number},
            leverage: %{type: :number},
            portfolio_concentration: %{type: :number},
            liquidation_risk: %{type: :number},
            unrealized_pnl: %{type: :number}
          }
        }
      },
      required: ["status", "order_result"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python
  require Logger

  def handler(input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- {:ok, Config.hyperliquid_account_address()},
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.exchange"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, risk_assessment} <- maybe_assess_risk(private_key, address, api_url, input),
         {:ok, result} <- execute_order(private_key, address, api_url, input) do
      {:ok,
       %{
         status: "success",
         order_result: result,
         risk_assessment: risk_assessment
       }}
    else
      {:error, :missing_private_key} ->
        {:error, "Hyperliquid account private key is not configured"}

      {:error, :missing_api_url} ->
        {:error, "Hyperliquid API URL is not configured"}

      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import required packages: #{error}"}

      {:error, {:risk_check_failed, reason}} ->
        {:error, "Risk check failed: #{reason}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_private_key do
    {:ok, Config.hyperliquid_account_key()}
  rescue
    RuntimeError -> {:error, :missing_private_key}
  end

  defp maybe_assess_risk(_private_key, _address, _api_url, %{skip_risk_checks: true}), do: {:ok, nil}

  defp maybe_assess_risk(private_key, address, api_url, params) do
    if risk_checks_enabled?(params) do
      assess_risk(private_key, address, api_url, params)
    else
      {:ok, nil}
    end
  end

  defp risk_checks_enabled?(params) do
    Map.has_key?(params, :max_position_size_ratio) ||
      Map.has_key?(params, :max_leverage) ||
      Map.has_key?(params, :min_liquidation_distance)
  end

  defp assess_risk(private_key, address, api_url, params) do
    python_result =
      python variables: %{
               private_key: private_key,
               address: address,
               api_url: api_url,
               params: params
             } do
        ~PY"""
        from hyperliquid_utils.setup import setup

        _, info, _ = setup(private_key, address, api_url, skip_ws=True)

        user_state = info.user_state(address)
        meta_and_ctxs = info.meta_and_asset_ctxs()

        coin = params["coin"]
        mark_px = None
        for idx, token in enumerate(meta_and_ctxs[0]["universe"]):
            if token["name"] == coin:
                mark_px = float(meta_and_ctxs[1][idx]["markPx"])
                break

        if mark_px is None:
            raise ValueError(f"Unknown coin: {coin}")

        margin_summary = user_state["crossMarginSummary"]
        account_value = float(margin_summary["accountValue"])
        total_ntl_pos = float(margin_summary["totalNtlPos"])

        trade_value = float(params["sz"]) * mark_px

        position_size_ratio = trade_value / account_value if account_value > 0 else 0.0
        resulting_ntl = total_ntl_pos + trade_value
        resulting_leverage = resulting_ntl / account_value if account_value > 0 else 0.0

        current_position = None
        for pos in user_state.get("assetPositions", []):
            if pos["position"]["coin"] == coin:
                current_position = pos
                break

        concentration = 0.0
        liquidation_risk = 0.0
        unrealized_pnl = 0.0

        if current_position:
            position_value = float(current_position["position"]["positionValue"])
            concentration = position_value / account_value if account_value > 0 else 0.0
            unrealized_pnl = float(current_position["position"].get("returnOnEquity", 0.0))

            liq_px = current_position["position"].get("liquidationPx")
            if liq_px not in (None, "nil", ""):
                liquidation_risk = abs(float(liq_px) - mark_px) / mark_px

        {
            "position_size_ratio": position_size_ratio,
            "leverage": resulting_leverage,
            "portfolio_concentration": concentration,
            "liquidation_risk": liquidation_risk,
            "unrealized_pnl": unrealized_pnl
        }
        """
      end

    case python_result do
      %{"error" => error} ->
        Logger.error("Risk assessment failed: #{inspect(error)}")
        {:error, {:risk_check_failed, error}}

      metrics when is_map(metrics) ->
        Logger.info("Risk assessment completed: #{inspect(metrics)}")
        validate_risk_metrics(metrics, params)
    end
  end

  defp validate_risk_metrics(metrics, params) do
    cond do
      exceeds?(params, :max_position_size_ratio, metrics["position_size_ratio"]) ->
        {:error,
         {:risk_check_failed,
          "position size ratio #{metrics["position_size_ratio"]} exceeds max #{params[:max_position_size_ratio]}"}}

      exceeds?(params, :max_leverage, metrics["leverage"]) ->
        {:error,
         {:risk_check_failed,
          "resulting leverage #{metrics["leverage"]} exceeds max #{params[:max_leverage]}"}}

      below_min?(params, :min_liquidation_distance, metrics["liquidation_risk"]) ->
        {:error,
         {:risk_check_failed,
          "liquidation distance #{metrics["liquidation_risk"]} below min #{params[:min_liquidation_distance]}"}}

      true ->
        {:ok, metrics}
    end
  end

  defp exceeds?(params, key, value) do
    case Map.get(params, key) do
      nil -> false
      max -> value > max
    end
  end

  defp below_min?(params, key, value) do
    case Map.get(params, key) do
      nil -> false
      min -> value < min
    end
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
        if params.get("vault_address"):
            exchange = Exchange(
                exchange.wallet,
                exchange.base_url,
                account_address=address,
                vault_address=params["vault_address"]
            )

        # Apply leverage / margin mode if requested
        if params.get("leverage") is not None:
            is_cross = params.get("is_cross", True)
            exchange.update_leverage(int(params["leverage"]), params["coin"], is_cross=is_cross)

        order_type = params["order_type"]

        if "limit" in order_type:
            tif = order_type["limit"]["tif"]
            result = exchange.order(
                params["coin"],
                params["is_buy"],
                float(params["sz"]),
                float(params["limit_px"]),
                {"limit": {"tif": tif}},
                reduce_only=bool(params.get("reduce_only", False))
            )
        elif "trigger" in order_type:
            trigger = order_type["trigger"]
            result = exchange.order(
                params["coin"],
                params["is_buy"],
                float(params["sz"]),
                float(params["limit_px"]),
                {
                    "trigger": {
                        "triggerPx": float(trigger["triggerPx"]),
                        "isMarket": bool(trigger["isMarket"]),
                        "tpsl": trigger["tpsl"]
                    }
                },
                reduce_only=bool(params.get("reduce_only", False))
            )
        else:
            raise ValueError("Unsupported order_type: %s" % order_type)

        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end