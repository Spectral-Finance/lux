defmodule Lux.Prisms.TradeProposalPrism do
  @moduledoc false
  use Lux.Prism,
    name: "Trade Proposal Prism",
    description: "A prism for evaluating trade proposals"

  alias Lux.Agents.RiskManager
  alias Lux.Beams.Hyperliquid.TradeRiskManagementBeam

  require Logger

  def handler(input, context) do
    Logger.info("Evaluating trade proposal: #{inspect(input)}")

    # First get agent's opinion on the trade
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
        Logger.info("LLM approved trade, running risk management beam")
        # Run the trade through the risk management beam
        case TradeRiskManagementBeam.run(%{
               address: Lux.Config.hyperliquid_account_address(),
               trade: Map.delete(input.payload, "rationale")
             }) do
          {:ok, result, _metadata} ->
            Logger.info("Risk management beam result: #{inspect(result)}")
            {:ok, result}

          {:error, reason, _metadata} ->
            Logger.warning("Risk management beam rejected trade: #{inspect(reason)}")
            {:ok, %{status: "rejected", reason: reason}}
        end

      %{"execute_trade" => false, "reasoning" => reason} ->
        Logger.info("LLM rejected trade: #{inspect(reason)}")
        {:ok, %{status: "rejected", reason: reason}}
    end
  end
end
