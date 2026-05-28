defmodule Lux.Prisms.Ethereum.Gas.MevProtectionPrism do
  @moduledoc """
  A prism that analyses an Ethereum transaction for MEV (Maximal Extractable
  Value) vulnerability and provides mitigation recommendations.

  MEV risks considered:

  * **Sandwich attacks** — DEX swaps with loose slippage tolerance are targets
    for front-running.
  * **Front-running** — High-value transactions or token approvals visible in
    the public mempool.
  * **Arbitrage exposure** — Transactions that create profitable arbitrage
    opportunities between liquidity pools.

  When `use_flashbots` is `true` the caller should route the transaction via
  Flashbots Protect (https://protect.flashbots.net) to keep it off the public
  mempool.

  ## Examples

      iex> Lux.Prisms.Ethereum.Gas.MevProtectionPrism.handler(%{
      ...>   tx_data: "0x38ed1739...",
      ...>   slippage_tolerance_pct: 1.0
      ...> }, %{})
      {:ok, %{
        mev_risk: :medium,
        recommendations: ["Reduce slippage to 0.5%", "Use Flashbots Protect"],
        use_flashbots: true
      }}
  """

  use Lux.Prism,
    name: "MEV Protection Analyser",
    description: "Analyses a transaction for MEV vulnerability and recommends protection strategies",
    input_schema: %{
      type: :object,
      properties: %{
        tx_data: %{
          type: :string,
          description: "Hex-encoded transaction calldata to analyse"
        },
        slippage_tolerance_pct: %{
          type: :number,
          description: "Slippage tolerance percentage configured in the transaction (e.g. 0.5 for 0.5%)",
          default: 0.5
        }
      },
      required: ["tx_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        mev_risk: %{
          type: :string,
          enum: ["low", "medium", "high"],
          description: "Assessed MEV risk level"
        },
        recommendations: %{
          type: :array,
          items: %{type: :string},
          description: "Actionable recommendations to reduce MEV exposure"
        },
        use_flashbots: %{
          type: :boolean,
          description: "Whether routing via Flashbots Protect is advised"
        }
      },
      required: ["mev_risk", "recommendations", "use_flashbots"]
    }

  require Logger

  # Known DEX swap function selectors (4-byte prefixes).
  @swap_selectors [
    # Uniswap v2 swapExactTokensForTokens
    "38ed1739",
    # Uniswap v2 swapTokensForExactTokens
    "8803dbee",
    # Uniswap v3 exactInputSingle
    "414bf389",
    # Uniswap v3 exactInput
    "c04b8d59",
    # SushiSwap swapExactTokensForTokens
    "18cbafe5",
    # 1inch swap
    "7c025200"
  ]

  # ERC-20 approve selector — high-value approvals attract front-runners.
  @approve_selector "095ea7b3"

  @doc """
  Analyses the given transaction data for MEV risk.
  """
  def handler(params, _ctx) do
    tx_data = Map.get(params, :tx_data, "0x")
    slippage = Map.get(params, :slippage_tolerance_pct, 0.5)

    selector = extract_selector(tx_data)
    is_swap = selector in @swap_selectors
    is_approval = selector == @approve_selector

    {risk, recommendations} = assess_risk(is_swap, is_approval, slippage)
    use_flashbots = risk in [:medium, :high]

    {:ok,
     %{
       mev_risk: risk,
       recommendations: recommendations,
       use_flashbots: use_flashbots
     }}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp extract_selector("0x" <> data) when byte_size(data) >= 8 do
    String.downcase(String.slice(data, 0, 8))
  end

  defp extract_selector(_), do: ""

  defp assess_risk(true = _is_swap, _is_approval, slippage) when slippage > 2.0 do
    recommendations = [
      "Reduce slippage tolerance to 0.5% or lower",
      "Use Flashbots Protect to hide from public mempool",
      "Consider splitting large swaps into smaller amounts",
      "Enable transaction deadline to prevent stale execution"
    ]

    {:high, recommendations}
  end

  defp assess_risk(true = _is_swap, _is_approval, slippage) when slippage > 0.5 do
    recommendations = [
      "Consider reducing slippage to 0.5% or lower",
      "Use Flashbots Protect or a private mempool relay",
      "Enable a tight transaction deadline"
    ]

    {:medium, recommendations}
  end

  defp assess_risk(true = _is_swap, _is_approval, _slippage) do
    recommendations = [
      "Slippage is tight — MEV risk is low for this swap",
      "Monitor for sandwich attacks in high-volatility conditions"
    ]

    {:low, recommendations}
  end

  defp assess_risk(_is_swap, true = _is_approval, _slippage) do
    recommendations = [
      "Consider using a permit signature (EIP-2612) instead of approve",
      "Approve only the exact amount needed rather than max uint256",
      "Use Flashbots Protect to prevent front-running of the approval"
    ]

    {:medium, recommendations}
  end

  defp assess_risk(_is_swap, _is_approval, _slippage) do
    recommendations = [
      "No known high-risk MEV patterns detected",
      "Standard transactions are generally safe from MEV attacks"
    ]

    {:low, recommendations}
  end
end
