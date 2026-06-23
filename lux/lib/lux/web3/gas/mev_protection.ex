defmodule Lux.Web3.Gas.MEVProtection do
  @moduledoc """
  MEV (Miner Extractable Value) protection analysis.
  """

  alias Lux.Web3.Gas.Types

  @doc """
  Analyzes a transaction for MEV risks.
  """
  @spec analyze(map()) :: {:ok, Types.MEVAnalysis.t()} | {:error, term()}
  def analyze(tx) when is_map(tx) do
    value = Map.get(tx, :value, 0)
    data = Map.get(tx, :data, "")
    to = Map.get(tx, :to, "")

    risk_factors = evaluate_risk_factors(value, data, to)
    risk_level = classify_risk(risk_factors)

    analysis = %Types.MEVAnalysis{
      risk_level: risk_level,
      is_front_running_risk: Map.get(risk_factors, :front_running, false),
      is_sandwich_attack_risk: Map.get(risk_factors, :sandwich, false),
      recommended_private_relay: risk_level in [:medium, :high],
      suggestions: generate_suggestions(risk_level, risk_factors)
    }

    {:ok, analysis}
  end

  @doc """
  Determines if a destination address is a known DEX/router contract.
  """
  @spec is_dex_interaction?(String.t()) :: boolean()
  def is_dex_interaction?(address) when is_binary(address) do
    lower = String.downcase(address)
    dex_routers = [
      "0x7a250d5c35b",
      "0xe592427a0ae",
      "0x1111111",
      "0xdef1"
    ]

    Enum.any?(dex_routers, fn prefix -> String.starts_with?(lower, prefix) end)
  end

  def is_dex_interaction?(_), do: false

  defp evaluate_risk_factors(value, data, to) do
    front_running = value > 1_000_000_000_000_000_000
    sandwich = is_dex_interaction?(to) and byte_size(data) > 68

    %{
      front_running: front_running,
      sandwich: sandwich,
      value: value,
      is_swap: sandwich
    }
  end

  defp classify_risk(%{front_running: true, sandwich: true}), do: :high
  defp classify_risk(%{front_running: true}), do: :medium
  defp classify_risk(%{sandwich: true}), do: :medium
  defp classify_risk(_), do: :low

  defp generate_suggestions(:low, _), do: ["Transaction appears low-risk, standard relay is fine."]

  defp generate_suggestions(:medium, %{is_swap: true}) do
    [
      "Consider using a private relay (Flashbots Protect, MEV-Share) to avoid sandwich attacks.",
      "Set a slippage tolerance of <= 0.5% for DEX swaps."
    ]
  end

  defp generate_suggestions(:medium, _) do
    [
      "Consider using a private relay for additional protection.",
      "Monitor mempool for competing transactions."
    ]
  end

  defp generate_suggestions(:high, _) do
    [
      "HIGH RISK: Use a private relay (Flashbots, MEV-Share) immediately.",
      "Split large transactions into smaller batches to reduce exposure.",
      "Set tight slippage tolerance (<= 0.1%) for DEX swaps.",
      "Consider using a private RPC endpoint."
    ]
  end
end
