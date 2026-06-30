defmodule Lux.Agents.MarketResearcher do
  @moduledoc """
  An agent that analyzes market conditions and proposes trades based on research.
  """

  use Lux.Agent,
    name: "Market Research Agent",
    description: "Analyzes markets and proposes trading opportunities",
    goal: "Find profitable trading opportunities through market analysis",
    capabilities: [:market_research, :trade_proposals],
    llm_config: %{
      model: "gpt-4o-mini",
      temperature: 0.7,
      json_response: true,
      json_schema: %{
        name: "trade_proposal",
        schema: %{
          type: "object",
          properties: %{
            coin: %{
              type: "string",
              description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
            },
            is_buy: %{
              type: "boolean",
              description: "True for buy orders, false for sell orders"
            },
            sz: %{
              type: "number",
              description: "Position size in base currency units"
            },
            limit_px: %{
              type: "number",
              description: "Limit price for the order"
            },
            order_type: %{
              type: "object",
              properties: %{
                limit: %{
                  type: "object",
                  properties: %{
                    tif: %{
                      type: "string",
                      enum: ["Gtc"],
                      description: "Time in force - Good till cancelled"
                    }
                  },
                  required: ["tif"]
                }
              },
              required: ["limit"]
            },
            reduce_only: %{
              type: "boolean",
              description: "Whether this order can only reduce position size"
            },
            rationale: %{
              type: "string",
              description: "Detailed explanation of the trade recommendation"
            }
          },
          required: [
            "coin",
            "is_buy",
            "sz",
            "limit_px",
            "order_type",
            "reduce_only",
            "rationale"
          ]
        }
      },
      messages: [
        %{
          role: "system",
          content: """
          You are a Market Research Agent specialized in analyzing cryptocurrency markets
          and proposing trades. Your recommendations must be in valid JSON format and include
          ALL of the following fields:

          {
            "coin": "string (e.g., 'ETH', 'BTC')",
            "is_buy": boolean,
            "sz": number,
            "limit_px": number,
            "order_type": {
              "limit": {
                "tif": "Gtc"
              }
            },
            "reduce_only": boolean,
            "rationale": "string explaining the trade"
          }

          Always include every field with appropriate values based on your analysis.
          """
        }
      ]
    }

  require Logger

  def propose_trade(agent, market_conditions) do
    with {:ok, trade_proposal} <-
           send_message(agent, """
           Based on these market conditions, propose a trade:
           #{Jason.encode!(market_conditions, pretty: true)}

           Respond with a complete trade proposal including ALL required fields.
           """) do
      {:ok, Jason.decode!(trade_proposal, keys: :atoms)}
    end
  end
end
