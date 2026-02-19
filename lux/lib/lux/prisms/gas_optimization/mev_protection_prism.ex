defmodule Lux.Prisms.GasOptimization.MEVProtectionPrism do
  @moduledoc """
  A prism that analyzes transactions for MEV (Maximal Extractable Value) vulnerabilities
  and provides protection strategies.

  ## MEV Attack Types Detected

  - **Sandwich Attacks**: Front/back-running around DEX swaps
  - **Frontrunning**: Transaction ordering exploitation
  - **Backrunning**: Extracting value from state changes after a tx
  - **Liquidation MEV**: Competing for liquidation opportunities

  ## Protection Strategies

  - **Flashbots Protect**: Route through Flashbots to avoid public mempool
  - **Private Mempool**: Use private transaction submission
  - **Slippage Guard**: Enforce strict slippage tolerance
  - **Commit-Reveal**: Two-phase transaction pattern

  ## Examples

      iex> Lux.Prisms.GasOptimization.MEVProtectionPrism.run(%{
      ...>   transaction: %{
      ...>     to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
      ...>     data: "0x38ed1739...",
      ...>     value: "1000000000000000000",
      ...>     type: "swap"
      ...>   }
      ...> })
      {:ok, %{
        risk_level: "high",
        mev_risks: ["sandwich_attack", "frontrunning"],
        recommended_protections: [...],
        estimated_mev_exposure_eth: 0.05
      }}
  """

  use Lux.Prism,
    name: "MEV Protection Analyzer",
    description: "Analyzes transactions for MEV vulnerabilities and recommends protection strategies",
    input_schema: %{
      type: :object,
      properties: %{
        transaction: %{
          type: :object,
          description: "Transaction to analyze for MEV risk",
          properties: %{
            to: %{type: :string, description: "Target contract address"},
            data: %{type: :string, description: "Transaction calldata"},
            value: %{type: :string, description: "ETH value in wei"},
            type: %{
              type: :string,
              enum: ["swap", "liquidity", "transfer", "approval", "contract_call", "unknown"],
              description: "Transaction type hint",
              default: "unknown"
            },
            token_amount: %{type: :number, description: "Token amount involved"},
            slippage_tolerance: %{type: :number, description: "Current slippage tolerance %"}
          },
          required: ["to"]
        },
        value_eth: %{
          type: :number,
          description: "Transaction value in ETH for exposure calculation"
        },
        network: %{
          type: :string,
          enum: ["mainnet", "goerli", "sepolia"],
          default: "mainnet"
        }
      },
      required: ["transaction"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        risk_level: %{type: :string, enum: ["none", "low", "medium", "high", "critical"]},
        mev_risks: %{type: :array, items: %{type: :string}},
        recommended_protections: %{type: :array},
        estimated_mev_exposure_eth: %{type: :number},
        safe_submission_methods: %{type: :array}
      }
    }

  require Logger

  # Known DEX router addresses (lowercase)
  @known_dex_routers [
    "0x7a250d5630b4cf539739df2c5dacb4c659f2488d",   # Uniswap V2
    "0xe592427a0aece92de3edee1f18e0157c05861564",   # Uniswap V3
    "0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f",   # SushiSwap
    "0x1111111254fb6c44bac0bed2854e76f90643097d",   # 1inch V4
    "0x1111111254eeb25477b68fb85ed929f73a960582",   # 1inch V5
    "0xdef1c0ded9bec7f1a1670819833240f027b25eff"    # 0x Exchange
  ]

  # Known swap function selectors (first 4 bytes / 10 hex chars)
  @swap_selectors [
    "0x38ed1739",  # swapExactTokensForTokens
    "0x8803dbee",  # swapTokensForExactTokens
    "0x7ff36ab5",  # swapExactETHForTokens
    "0x18cbafe5",  # swapExactTokensForETH
    "0xfb3bdb41",  # swapETHForExactTokens
    "0x5c11d795",  # swapExactTokensForTokensSupportingFeeOnTransferTokens
    "0xb6f9de95",  # swapExactETHForTokensSupportingFeeOnTransferTokens
    "0x791ac947",  # swapExactTokensForETHSupportingFeeOnTransferTokens
    "0x414bf389",  # exactInputSingle (Uniswap V3)
    "0xc04b8d59",  # exactInput (Uniswap V3)
    "0xdb3e2198",  # exactOutputSingle (Uniswap V3)
    "0xf28c0498"   # exactOutput (Uniswap V3)
  ]

  # Liquidity function selectors
  @liquidity_selectors [
    "0xe8e33700",  # addLiquidity
    "0xf305d719",  # addLiquidityETH
    "0xbaa2abde",  # removeLiquidity
    "0x02751cec"   # removeLiquidityETH
  ]

  def handler(input, _ctx) do
    transaction = Map.get(input, :transaction, %{})
    value_eth = Map.get(input, :value_eth, 0)
    network = Map.get(input, :network, "mainnet")

    # Detect transaction type
    tx_type = detect_transaction_type(transaction)

    # Analyze MEV risks
    risks = analyze_mev_risks(transaction, tx_type, value_eth)

    # Calculate risk level
    risk_level = calculate_risk_level(risks, value_eth)

    # Generate protection recommendations
    protections = recommend_protections(risks, risk_level, network)

    # Calculate MEV exposure
    exposure = estimate_mev_exposure(risks, value_eth, tx_type)

    # Safe submission methods
    submission_methods = safe_submission_methods(risk_level, network)

    {:ok,
     %{
       risk_level: risk_level,
       detected_tx_type: tx_type,
       mev_risks: Enum.map(risks, & &1.type),
       risk_details: risks,
       recommended_protections: protections,
       estimated_mev_exposure_eth: Float.round(exposure, 6),
       safe_submission_methods: submission_methods,
       network: network
     }}
  end

  @doc """
  Detects the transaction type from calldata and target address.
  """
  def detect_transaction_type(transaction) do
    explicit_type = get_field(transaction, :type)
    to = get_field(transaction, :to, "") |> String.downcase()
    data = get_field(transaction, :data, "")

    cond do
      explicit_type not in [nil, "unknown"] ->
        explicit_type

      is_dex_router?(to) and is_swap?(data) ->
        "swap"

      is_dex_router?(to) and is_liquidity_op?(data) ->
        "liquidity"

      data in ["", "0x", nil] ->
        "transfer"

      String.starts_with?(data, "0x095ea7b3") ->
        "approval"

      true ->
        "contract_call"
    end
  end

  @doc """
  Analyzes potential MEV risks for a transaction.
  """
  def analyze_mev_risks(transaction, tx_type, value_eth) do
    risks = []

    risks = risks ++ check_sandwich_risk(tx_type, value_eth, transaction)
    risks = risks ++ check_frontrunning_risk(tx_type, value_eth)
    risks = risks ++ check_backrunning_risk(tx_type)
    risks = risks ++ check_slippage_risk(transaction)

    risks
  end

  defp check_sandwich_risk(tx_type, value_eth, transaction) do
    if tx_type == "swap" do
      slippage = get_field(transaction, :slippage_tolerance, 0.5)
      severity = cond do
        value_eth > 10 and slippage > 1.0 -> "critical"
        value_eth > 1 and slippage > 0.5 -> "high"
        value_eth > 0.1 -> "medium"
        true -> "low"
      end

      [%{
        type: "sandwich_attack",
        severity: severity,
        description: "DEX swaps are vulnerable to sandwich attacks where an attacker front-runs and back-runs your trade",
        mitigation: "Use Flashbots Protect or set tight slippage tolerance"
      }]
    else
      []
    end
  end

  defp check_frontrunning_risk(tx_type, value_eth) do
    if tx_type in ["swap", "liquidity", "contract_call"] and value_eth > 0.5 do
      severity = if value_eth > 5, do: "high", else: "medium"

      [%{
        type: "frontrunning",
        severity: severity,
        description: "Transaction may be frontrun by bots monitoring the mempool",
        mitigation: "Submit through private mempool or use commit-reveal pattern"
      }]
    else
      []
    end
  end

  defp check_backrunning_risk(tx_type) do
    if tx_type in ["swap", "liquidity"] do
      [%{
        type: "backrunning",
        severity: "low",
        description: "Arbitrage bots may extract value from price impact after your trade",
        mitigation: "Break large trades into smaller chunks"
      }]
    else
      []
    end
  end

  defp check_slippage_risk(transaction) do
    slippage = get_field(transaction, :slippage_tolerance)

    if is_number(slippage) and slippage > 3.0 do
      [%{
        type: "excessive_slippage",
        severity: "high",
        description: "Slippage tolerance of #{slippage}% is dangerously high, inviting MEV extraction",
        mitigation: "Reduce slippage tolerance to 0.5-1.0% for most trades"
      }]
    else
      []
    end
  end

  defp calculate_risk_level(risks, value_eth) do
    severities = Enum.map(risks, & &1.severity)

    cond do
      Enum.empty?(risks) -> "none"
      "critical" in severities -> "critical"
      "high" in severities and value_eth > 1 -> "high"
      "high" in severities -> "medium"
      "medium" in severities -> "medium"
      true -> "low"
    end
  end

  defp recommend_protections(risks, risk_level, network) do
    base_protections = []

    base_protections =
      if risk_level in ["high", "critical"] do
        base_protections ++
          [
            %{
              method: "flashbots_protect",
              description: "Route transaction through Flashbots Protect RPC to avoid public mempool",
              rpc_url: "https://rpc.flashbots.net",
              priority: "recommended"
            }
          ]
      else
        base_protections
      end

    base_protections =
      if Enum.any?(risks, &(&1.type == "sandwich_attack")) do
        base_protections ++
          [
            %{
              method: "slippage_guard",
              description: "Set strict slippage tolerance (0.5% recommended)",
              recommended_slippage: 0.5,
              priority: "recommended"
            },
            %{
              method: "trade_splitting",
              description: "Split large trades into smaller chunks to reduce price impact",
              priority: "optional"
            }
          ]
      else
        base_protections
      end

    base_protections =
      if risk_level in ["medium", "high", "critical"] and network == "mainnet" do
        base_protections ++
          [
            %{
              method: "private_mempool",
              description: "Submit transaction to a private mempool (e.g., Flashbots, bloXroute)",
              priority: "recommended"
            }
          ]
      else
        base_protections
      end

    if Enum.empty?(base_protections) do
      [%{
        method: "standard_submission",
        description: "Transaction has low MEV risk, standard submission is acceptable",
        priority: "default"
      }]
    else
      base_protections
    end
  end

  defp estimate_mev_exposure(risks, value_eth, tx_type) do
    if Enum.empty?(risks) or value_eth == 0 do
      0.0
    else
      # Rough estimation based on tx type and value
      base_exposure = case tx_type do
        "swap" -> value_eth * 0.005     # ~0.5% for swaps
        "liquidity" -> value_eth * 0.003 # ~0.3% for liquidity
        _ -> value_eth * 0.001           # ~0.1% for others
      end

      # Adjust by severity
      max_severity = risks
        |> Enum.map(& &1.severity)
        |> Enum.map(fn
          "critical" -> 3.0
          "high" -> 2.0
          "medium" -> 1.0
          _ -> 0.5
        end)
        |> Enum.max(fn -> 1.0 end)

      base_exposure * max_severity
    end
  end

  defp safe_submission_methods(risk_level, network) do
    case {risk_level, network} do
      {"none", _} -> ["public_mempool"]
      {"low", _} -> ["public_mempool", "flashbots_protect"]
      {_, "mainnet"} -> ["flashbots_protect", "mev_blocker", "private_rpc"]
      _ -> ["private_rpc"]
    end
  end

  defp is_dex_router?(address) do
    String.downcase(address) in @known_dex_routers
  end

  defp is_swap?(data) when is_binary(data) do
    selector = String.slice(data, 0, 10)
    selector in @swap_selectors
  end

  defp is_swap?(_), do: false

  defp is_liquidity_op?(data) when is_binary(data) do
    selector = String.slice(data, 0, 10)
    selector in @liquidity_selectors
  end

  defp is_liquidity_op?(_), do: false

  defp get_field(map, key, default \\ nil) when is_atom(key) do
    Map.get(map, key) || Map.get(map, to_string(key)) || default
  end
end
