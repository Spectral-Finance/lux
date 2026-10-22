defmodule Lux.Beams.Hyperliquid.PerpetualTradingBeam do
  @moduledoc """
  An autonomous execution beam for Hyperliquid perpetual trading with integrated risk checks and leverage configuration.

  ## Example

      Lux.Beams.Hyperliquid.PerpetualTradingBeam.run(%{
        address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5",
        trade: %{
          coin: "BTC",
          is_buy: true,
          sz: 0.1,
          limit_px: 68000.0,
          order_type: %{limit: %{tif: "Gtc"}},
          reduce_only: false,
          leverage: 10
        }
      })
  """

  use Lux.Beam,
    name: "Hyperliquid Autonomous Perpetual Trading",
    description: "Evaluates risk, configures leverage, and executes perpetual trades",
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
            reduce_only: %{type: :boolean},
            leverage: %{type: :integer}
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
          description: "Execution status (success or rejected)"
        },
        order_result: %{
          type: :object,
          description: "Execution response or rejection diagnostics"
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
    step(:portfolio_state, HyperliquidUserStatePrism, %{
      address: Config.hyperliquid_account_address()
    })

    step(:market_data, HyperliquidTokenInfoPrism, %{})

    step(:risk_assessment, HyperliquidRiskAssessmentPrism, %{
      portfolio: [:steps, :portfolio_state, :result, :user_state],
      market_data: [:steps, :market_data, :result, :prices],
      proposed_trade: [:input, :trade]
    })

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
  Determines if the perpetual trade should be executed based on risk metrics.
  """
  def should_execute?(ctx) do
    metrics = ctx.steps.risk_assessment.result

    metrics["position_size_ratio"] <= 0.25 and
      metrics["leverage"] <= 10.0 and
      metrics["portfolio_concentration"] <= 0.5 and
      metrics["liquidation_risk"] <= 0.15
  end
end
