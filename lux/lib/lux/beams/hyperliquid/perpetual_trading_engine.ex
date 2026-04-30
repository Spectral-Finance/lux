defmodule Lux.Beams.Hyperliquid.PerpetualTradingEngine do
  @moduledoc """
  A beam that orchestrates the full perpetual trading workflow on Hyperliquid.

  This beam coordinates the complete perpetual trading lifecycle including:
  1. Market data collection and analysis
  2. Position tracking and risk assessment
  3. Leverage and margin management
  4. Order execution with risk controls
  5. Post-trade monitoring and protection

  It integrates all the lenses and prisms to provide a comprehensive perpetual
  trading system with built-in risk management and liquidation protection.

  ## Example

      # Execute a perpetual trade with full risk management
      iex> Lux.Beams.Hyperliquid.PerpetualTradingEngine.run(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5",
      ...>   trade: %{
      ...>     coin: "ETH",
      ...>     is_buy: true,
      ...>     sz: 0.5,
      ...>     limit_px: 2800.0,
      ...>     order_type: %{limit: %{tif: "Gtc"}},
      ...>     reduce_only: false
      ...>   },
      ...>   risk_params: %{
      ...>     max_leverage: 5.0,
      ...>     stop_loss_pct: 0.05,
      ...>     take_profit_pct: 0.10,
      ...>     max_position_size_pct: 0.20
      ...>   }
      ...> })
      {:ok, %{
        status: "executed",
        trade_result: %{...},
        risk_metrics: %{...},
        position: %{...},
        protection: %{...}
      }}

  The beam reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Beam,
    name: "Hyperliquid Perpetual Trading Engine",
    description: "Orchestrates the full perpetual trading workflow with risk management",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Trading account address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        trade: %{
          type: :object,
          properties: %{
            coin: %{type: :string},
            is_buy: %{type: :boolean},
            sz: %{type: :number},
            limit_px: %{type: :number},
            order_type: %{type: :object},
            reduce_only: %{type: :boolean}
          },
          required: ["coin", "is_buy", "sz", "limit_px", "order_type"]
        },
        risk_params: %{
          type: :object,
          properties: %{
            max_leverage: %{type: :number},
            stop_loss_pct: %{type: :number},
            take_profit_pct: %{type: :number},
            max_position_size_pct: %{type: :number}
          }
        }
      },
      required: ["address", "trade"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{
          type: :string,
          description: "Trade status (executed, rejected, protected)"
        },
        trade_result: %{
          type: :object,
          description: "Order execution result"
        },
        risk_metrics: %{
          type: :object,
          description: "Risk metrics after trade"
        },
        position: %{
          type: :object,
          description: "Updated position information"
        },
        protection: %{
          type: :object,
          description: "Protection measures applied"
        }
      },
      required: ["status", "trade_result"]
    },
    generate_execution_log: true

  alias Lux.Config
  alias Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism
  alias Lux.Prisms.Hyperliquid.LeverageManagerPrism
  alias Lux.Prisms.Hyperliquid.MarginAllocatorPrism
  alias Lux.Prisms.Hyperliquid.LiquidationProtectionPrism
  alias Lux.Prisms.Hyperliquid.PnlAnalyzerPrism
  alias Lux.Prisms.NoOp

  require Logger

  sequence do
    # Step 1: Get current portfolio state
    step(:portfolio_state, HyperliquidUserStatePrism, %{
      address: Config.hyperliquid_account_address()
    })

    # Step 2: Get current market data
    step(:market_data, HyperliquidTokenInfoPrism, %{})

    # Step 3: Calculate leverage recommendations
    step(:leverage_check, LeverageManagerPrism, %{
      portfolio: [:steps, :portfolio_state, :result, :user_state],
      proposed_position: %{
        coin: [:input, :trade, :coin],
        sz: [:input, :trade, :sz],
        limit_px: [:input, :trade, :limit_px]
      },
      market_data: [:steps, :market_data, :result, :prices],
      risk_tolerance: [:input, :risk_params, :risk_tolerance]
    })

    # Step 4: Calculate margin allocation
    step(:margin_check, MarginAllocatorPrism, %{
      portfolio: [:steps, :portfolio_state, :result, :user_state],
      new_position: %{
        coin: [:input, :trade, :coin],
        sz: [:input, :trade, :sz],
        limit_px: [:input, :trade, :limit_px]
      },
      allocation_strategy: "risk_adjusted"
    })

    # Step 5: Risk assessment
    step(:risk_assessment, HyperliquidRiskAssessmentPrism, %{
      portfolio: [:steps, :portfolio_state, :result, :user_state],
      market_data: [:steps, :market_data, :result, :prices],
      proposed_trade: [:input, :trade]
    })

    # Step 6: Decision branch - execute or reject
    branch {__MODULE__, :should_execute?} do
      true ->
        sequence do
          # Execute the trade
          step(:execute_trade, HyperliquidExecuteOrderPrism, %{
            coin: [:input, :trade, :coin],
            is_buy: [:input, :trade, :is_buy],
            sz: [:input, :trade, :sz],
            limit_px: [:input, :trade, :limit_px],
            order_type: [:input, :trade, :order_type],
            reduce_only: [:input, :trade, :reduce_only]
          })

          # Set up liquidation protection
          step(:protection, LiquidationProtectionPrism, %{
            portfolio: [:steps, :portfolio_state, :result, :user_state],
            market_data: [:steps, :market_data, :result, :prices],
            protection_strategy: "set_stop_loss",
            safety_buffer: 0.15
          })

          # Analyze PnL
          step(:pnl_analysis, PnlAnalyzerPrism, %{
            portfolio: [:steps, :portfolio_state, :result, :user_state],
            market_data: [:steps, :market_data, :result, :prices],
            analysis_period: "24h"
          })
        end

      false ->
        step(:reject, NoOp, %{
          status: "rejected",
          trade_result: %{
            rejection_reason: "Failed risk assessment",
            risk_metrics: [:steps, :risk_assessment, :result],
            leverage_check: [:steps, :leverage_check, :result],
            margin_check: [:steps, :margin_check, :result]
          }
        })
    end
  end

  @doc """
  Determines if the trade should be executed based on all risk checks.
  """
  def should_execute?(ctx) do
    risk_metrics = ctx.steps.risk_assessment.result || %{}
    leverage_result = ctx.steps.leverage_check.result || %{}
    margin_result = ctx.steps.margin_check.result || %{}

    # Check risk thresholds
    position_size_ok = Map.get(risk_metrics, "position_size_ratio", 1.0) <= 0.2
    leverage_ok = Map.get(leverage_result, "risk_assessment", "critical") not in ["critical", "high"]
    margin_ok = Map.get(margin_result, :recommended_allocation, %{})["status"] in [nil, "approved", "partial"]
    concentration_ok = Map.get(risk_metrics, "portfolio_concentration", 1.0) <= 0.4

    position_size_ok and leverage_ok and margin_ok and concentration_ok
  end
end
