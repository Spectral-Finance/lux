defmodule Lux.Prisms.Gas.MEVProtectionPrism do
  @moduledoc """
  Analyzes transactions for MEV risk and recommends private transaction relays.
  """

  use Lux.Prism,
    name: "MEV Protection Analyzer",
    description: "Analyzes transactions for MEV risk and recommends private transaction relays",
    input_schema: %{
      type: :object,
      properties: %{
        tx_data: %{
          type: :object,
          properties: %{
            to: %{type: :string},
            value: %{type: :string},
            data: %{type: :string},
            from: %{type: :string}
          },
          required: ["to"]
        },
        network: %{type: :string, enum: ["mainnet", "goerli", "sepolia"], default: "mainnet"},
        gas_price_gwei: %{type: :number}
      },
      required: ["tx_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        mev_risk_level: %{type: :string, enum: ["low", "medium", "high", "critical"]},
        mev_risk_score: %{type: :number},
        risk_factors: %{type: :array, items: %{type: :string}},
        recommended_relay: %{type: :string},
        relay_endpoints: %{type: :object},
        estimated_mev_exposure_wei: %{type: :integer},
        protection_recommendation: %{type: :string}
      },
      required: ["mev_risk_level", "mev_risk_score", "risk_factors", "recommended_relay", "relay_endpoints", "estimated_mev_exposure_wei", "protection_recommendation"]
    }

  @known_dex_prefixes ["0x7a250d5c35b", "0x68b3465833b", "0x11111112542", "0xcde61034", "0x881d40", "0xdef1"]

  def handler(input, _ctx \ nil) do
    tx_data = Map.get(input, :tx_data, %{})
    network = Map.get(input, :network, "mainnet")
    gas_price_gwei = Map.get(input, :gas_price_gwei)

    risk_factors = analyze_risk_factors(tx_data, gas_price_gwei)
    risk_score = calculate_risk_score(risk_factors)
    risk_level = score_to_level(risk_score)
    relay = recommend_relay(risk_level)

    {:ok, %{
      mev_risk_level: risk_level,
      mev_risk_score: risk_score,
      risk_factors: risk_factors,
      recommended_relay: relay,
      relay_endpoints: get_relay_endpoints(relay, network),
      estimated_mev_exposure_wei: estimate_exposure(tx_data),
      protection_recommendation: generate_recommendation(risk_level, relay)
    }}
  end

  defp analyze_risk_factors(tx_data, gas_price_gwei) do
    to_addr = Map.get(tx_data, :to, "") |> String.downcase()
    data = Map.get(tx_data, :data, "0x")
    value = Map.get(tx_data, :value, "0") |> String.to_integer()
    factors = []

    if Enum.any?(@known_dex_prefixes, fn p -> String.starts_with?(to_addr, p) end) do
      factors = ["Interacting with DEX/router contract - frontrunning risk"] ++ factors
    end

    if data != "0x" and data != "0x0" do
      factors = ["Non-trivial calldata - potential MEV target"] ++ factors
    end

    if value > 10_000_000_000_000_000_000 do
      factors = ["High transaction value (>10 ETH) - significant MEV target"] ++ factors
    end

    if gas_price_gwei && gas_price_gwei > 100 do
      factors = ["High gas price (>100 GWei) - network congestion increases MEV risk"] ++ factors
    end

    Enum.reverse(factors)
  end

  defp calculate_risk_score(factors) do
    Enum.reduce(factors, 0.0, fn factor, acc ->
      cond do
        String.contains?(factor, "frontrunning") -> min(acc + 0.35, 1.0)
        String.contains?(factor, "MEV target") -> min(acc + 0.25, 1.0)
        String.contains?(factor, "calldata") -> min(acc + 0.15, 1.0)
        String.contains?(factor, "High transaction value") -> min(acc + 0.15, 1.0)
        String.contains?(factor, "gas price") -> min(acc + 0.10, 1.0)
        true -> min(acc + 0.05, 1.0)
      end
    end)
  end

  defp score_to_level(score) when score >= 0.7, do: "critical"
  defp score_to_level(score) when score >= 0.5, do: "high"
  defp score_to_level(score) when score >= 0.3, do: "medium"
  defp score_to_level(_score), do: "low"

  defp recommend_relay("critical"), do: "flashbots"
  defp recommend_relay("high"), do: "flashbots"
  defp recommend_relay("medium"), do: "flashbots"
  defp recommend_relay(_level), do: "default"

  defp get_relay_endpoints("flashbots", network) do
    %{mainnet: "https://rpc.flashbots.net", goerli: "https://rpc.goerli.flashbots.net", sepolia: "https://rpc.sepolia.flashbots.net"}
  end
  defp get_relay_endpoints("eden", network) do
    %{mainnet: "https://relay.edennetwork.io/v1/rpc", goerli: "https://relay.goerli.edennetwork.io/v1/rpc", sepolia: "https://relay.sepolia.edennetwork.io/v1/rpc"}
  end
  defp get_relay_endpoints(_, _), do: %{}

  defp estimate_exposure(tx_data) do
    value = Map.get(tx_data, :value, "0") |> String.to_integer()
    max(value * 5 div 100, 0)
  end

  defp generate_recommendation("critical", relay), do: "CRITICAL MEV risk. Use #{relay} private relay immediately."
  defp generate_recommendation("high", relay), do: "High MEV risk. Consider using #{relay} private relay."
  defp generate_recommendation("medium", relay), do: "Moderate MEV risk. Private relay recommended."
  defp generate_recommendation("low", _relay), do: "Low MEV risk. Standard submission is safe."
end
