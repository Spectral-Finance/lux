defmodule Lux.Agents.RiskManager do
  @moduledoc """
  An agent that evaluates trade proposals for risk and executes approved trades.
  """

  use Lux.Agent,
    name: "Risk Management Agent",
    description: "Evaluates and executes trades based on risk assessment",
    goal: "Ensure trades meet risk management criteria before execution",
    capabilities: [:risk_management, :trade_execution],
    accepts_signals: [Lux.Schemas.TradeProposalSchema],
    signal_handlers: [{Lux.Schemas.TradeProposalSchema, Lux.Prisms.TradeProposalPrism}],
    llm_config: %{
      model: "gpt-4o-mini",
      temperature: 0.3,
      json_response: true,
      json_schema: %{
        name: "risk_evaluation",
        schema: %{
          type: "object",
          properties: %{
            execute_trade: %{
              type: "boolean",
              description: "Whether to proceed with trade execution"
            },
            reasoning: %{
              type: "string",
              description: "Detailed explanation of the decision"
            }
          },
          required: ["execute_trade", "reasoning"],
          additionalProperties: false
        },
        strict: true
      },
      messages: [
        %{
          role: "system",
          content: """
          You are a Risk Management Agent responsible for evaluating trade proposals
          and executing trades that meet risk criteria. You will:

          1. Review trade proposals and their rationale
          2. Use the Risk Management Beam to evaluate trades
          3. Execute approved trades
          4. Provide feedback on rejected trades

          Respond with a structured evaluation including whether to execute the trade
          and your reasoning.
          """
        }
      ]
    }
end
