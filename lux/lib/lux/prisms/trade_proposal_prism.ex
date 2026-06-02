defmodule Lux.Prisms.TradeProposalPrism do
  @moduledoc false
  use Lux.Prism,
    name: "Trade Proposal Prism",
    description: "A prism for evaluating trade proposals"

  alias Lux.Agents.RiskManager

  require Logger

  def handler(input, context) do
    Logger.info("Evaluating trade proposal: #{inspect(input)}")

    # Get agent's opinion on the trade
    {:ok, evaluation} =
      RiskManager.chat(context, """
      Evaluate this trade proposal:
      #{Jason.encode!(input.payload)}

      Consider:
      1. Does the rationale make sense?
      2. Is the position size reasonable?
      3. Is the limit price realistic?
      """)

    Logger.info("LLM evaluation: #{inspect(evaluation)}")

    case Jason.decode!(evaluation) do
      %{"execute_trade" => true} ->
        Logger.info("LLM approved trade")
        {:ok, %{status: "approved", evaluation: evaluation}}

      %{"execute_trade" => false, "reasoning" => reason} ->
        Logger.info("LLM rejected trade: #{inspect(reason)}")
        {:ok, %{status: "rejected", reason: reason}}
    end
  end
end
