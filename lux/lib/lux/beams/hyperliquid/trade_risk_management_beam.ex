defmodule Lux.Beams.Hyperliquid.TradeRiskManagementBeam do
  @moduledoc """
  A beam that evaluates trade suggestions against risk management criteria and portfolio state.

  This beam:
  1. Fetches current portfolio state and positions
  2. Gets current market prices and conditions
  3. Evaluates the trade against risk management rules
  4. Either executes or rejects the trade based on risk assessment

  ## Example

      Lux.Beams.Hyperliquid.TradeRiskManagementBeam.run(%{
        address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5",
        trade: %{
          coin: "ETH",
          is_buy: true,
          sz: 0.1,
          limit_px: 2800.0,
          order_type: %{limit: %{tif: "Gtc"}},
          reduce_only: false
        }
      })
      {:ok, %{
        status: "accepted", # or "rejected"
        risk_metrics: %{
          position_size_ratio: 0.15,
          leverage: 2.0,
          portfolio_concentration: 0.25,
          # ... other metrics
        },
        execution_result: %{} # if accepted
      }}
  """

  use Lux.Beam,
    name: "Hyperliquid Trade Risk Management",
    description: "Evaluates and manages trade risk for Hyperliquid positions",
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
        }
      },
      required: ["address", "trade"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{
          type: :string,
          description: "Order status (success or rejected)"
        },
        order_result: %{
          type: :object,
          description: "Order execution result or rejection details"
        }
      },
      required: ["status", "order_result"]
    },
    generate_execution_log: true

  alias Lux.Config
  alias Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism

  require Logger

  sequence do
    # Get current portfolio state
    step(:portfolio_state, HyperliquidUserStatePrism, %{
      address: Config.hyperliquid_account_address()
    })

    # Get current market prices
    step(:market_data, HyperliquidTokenInfoPrism, %{})

    # Calculate risk metrics
    step(:risk_assessment, HyperliquidRiskAssessmentPrism, %{
      portfolio: [:steps, :portfolio_state, :result, :user_state],
      market_data: [:steps, :market_data, :result, :prices],
      proposed_trade: [:input, :trade]
    })

    # Decide whether to execute the trade
    branch {__MODULE__, :should_execute?} do
      true ->
        step(:execute_trade, HyperliquidExecuteOrderPrism, %{
          coin: [:input, :trade, :coin],
          is_buy: [:input, :trade, :is_buy],
          sz: [:input, :trade, :sz],
          limit_px: [:input, :trade, :limit_px],
          order_type: [:input, :trade, :order_type],
          reduce_only: [:input, :trade, :reduce_only]
        })

      false ->
        step(:return, Lux.Prisms.NoOp, %{
          status: "rejected",
          order_result: %{
            risk_metrics: [:steps, :risk_assessment, :result],
            rejection_reason: "Failed risk assessment checks"
          }
        })
    end
  end

  @doc """
  Determines if the trade should be executed based on risk metrics
  """
  def should_execute?(ctx) do
    metrics = ctx.steps.risk_assessment.result

    # Define risk thresholds
    metrics["position_size_ratio"] <= 0.2 and
      metrics["leverage"] <= 5.0 and
      metrics["portfolio_concentration"] <= 0.4 and
      metrics["liquidation_risk"] <= 0.1
  end
end
