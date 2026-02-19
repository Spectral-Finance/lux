defmodule Lux.Prisms.GasOptimization.CostOptimizerPrism do
  @moduledoc """
  A prism that provides comprehensive gas cost optimization strategies.

  Analyzes transaction patterns and network conditions to recommend
  the most cost-effective approach for transaction execution.

  ## Optimization Strategies

  - **Timing**: Identifies optimal times to submit transactions
  - **Batching**: Groups compatible transactions for gas savings
  - **Gas Token**: Evaluates gas token usage for refunds
  - **L2 Migration**: Suggests Layer 2 alternatives for cost reduction
  - **Contract Optimization**: Recommends calldata optimization techniques

  ## Examples

      iex> Lux.Prisms.GasOptimization.CostOptimizerPrism.run(%{
      ...>   transactions: [
      ...>     %{type: "erc20_transfer", gas_estimate: 65000, urgency: "low"},
      ...>     %{type: "swap", gas_estimate: 150000, urgency: "medium"}
      ...>   ],
      ...>   budget_eth: 0.01
      ...> })
      {:ok, %{
        total_estimated_cost_eth: 0.008,
        budget_remaining_eth: 0.002,
        within_budget: true,
        optimizations: [...],
        potential_savings_eth: 0.003
      }}
  """

  use Lux.Prism,
    name: "Gas Cost Optimizer",
    description: "Analyzes transactions and recommends cost optimization strategies",
    input_schema: %{
      type: :object,
      properties: %{
        transactions: %{
          type: :array,
          description: "Transactions to optimize",
          items: %{
            type: :object,
            properties: %{
              type: %{
                type: :string,
                enum: ["eth_transfer", "erc20_transfer", "erc20_approve", "swap", "nft_mint", "contract_call", "contract_deploy"],
                default: "contract_call"
              },
              gas_estimate: %{type: :integer, description: "Estimated gas usage"},
              urgency: %{
                type: :string,
                enum: ["low", "medium", "high", "critical"],
                default: "medium"
              },
              value_eth: %{type: :number, description: "Transaction value in ETH", default: 0}
            },
            required: ["type", "gas_estimate"]
          }
        },
        budget_eth: %{
          type: :number,
          description: "Maximum gas budget in ETH"
        },
        current_gas_gwei: %{
          type: :number,
          description: "Current gas price in Gwei (auto-fetched if omitted)"
        },
        optimization_level: %{
          type: :string,
          enum: ["basic", "standard", "aggressive"],
          description: "How aggressively to optimize",
          default: "standard"
        },
        network: %{
          type: :string,
          enum: ["mainnet", "goerli", "sepolia"],
          default: "mainnet"
        }
      },
      required: ["transactions"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_estimated_cost_eth: %{type: :number},
        budget_remaining_eth: %{type: :number},
        within_budget: %{type: :boolean},
        optimizations: %{type: :array},
        potential_savings_eth: %{type: :number},
        optimized_execution_plan: %{type: :array}
      }
    }

  require Logger

  # Gas estimates for common operations
  @operation_gas %{
    "eth_transfer" => 21_000,
    "erc20_transfer" => 65_000,
    "erc20_approve" => 46_000,
    "swap" => 150_000,
    "nft_mint" => 200_000,
    "contract_call" => 100_000,
    "contract_deploy" => 500_000
  }

  # L2 cost reduction factors (approximate)
  @l2_savings %{
    "arbitrum" => 0.05,
    "optimism" => 0.05,
    "polygon" => 0.01,
    "base" => 0.04,
    "zksync" => 0.03
  }

  def handler(input, _ctx) do
    transactions = Map.get(input, :transactions, [])
    budget = Map.get(input, :budget_eth)
    gas_price = Map.get(input, :current_gas_gwei)
    optimization_level = Map.get(input, :optimization_level, "standard")
    network = Map.get(input, :network, "mainnet")

    with {:ok, effective_gas_price} <- resolve_gas_price(gas_price, network) do
      normalized = normalize_transactions(transactions)
      analysis = analyze_costs(normalized, effective_gas_price)
      optimizations = generate_optimizations(normalized, analysis, effective_gas_price, optimization_level)
      execution_plan = build_execution_plan(normalized, optimizations, effective_gas_price)
      potential_savings = calculate_savings(optimizations, analysis.total_gas, effective_gas_price)

      budget_analysis = analyze_budget(analysis.total_cost_eth, potential_savings, budget)

      {:ok,
       %{
         total_estimated_cost_eth: Float.round(analysis.total_cost_eth, 8),
         total_gas: analysis.total_gas,
         gas_price_gwei: effective_gas_price,
         within_budget: budget_analysis.within_budget,
         budget_remaining_eth: budget_analysis.remaining,
         optimizations: optimizations,
         potential_savings_eth: Float.round(potential_savings, 8),
         potential_savings_pct: Float.round(potential_savings / max(analysis.total_cost_eth, 0.000001) * 100, 1),
         optimized_execution_plan: execution_plan,
         l2_alternatives: l2_alternatives(analysis.total_gas, effective_gas_price),
         network: network,
         transaction_count: length(normalized)
       }}
    end
  end

  defp resolve_gas_price(nil, network) do
    case Lux.Lenses.Etherscan.GasOracle.focus(%{chainid: chain_id(network)}) do
      {:ok, %{gas_oracle: oracle}} ->
        {:ok, parse_number(oracle.propose_gas_price, 20.0)}

      {:error, reason} ->
        Logger.warning("Could not fetch gas price, using default: #{inspect(reason)}")
        {:ok, 20.0}
    end
  end

  defp resolve_gas_price(gas_price, _network) when is_number(gas_price), do: {:ok, gas_price * 1.0}

  defp normalize_transactions(transactions) do
    Enum.with_index(transactions, 1)
    |> Enum.map(fn {tx, idx} ->
      type = get_field(tx, :type, "contract_call")
      gas = get_field(tx, :gas_estimate) || Map.get(@operation_gas, type, 100_000)

      %{
        index: idx,
        type: type,
        gas_estimate: gas,
        urgency: get_field(tx, :urgency, "medium"),
        value_eth: get_field(tx, :value_eth, 0)
      }
    end)
  end

  defp analyze_costs(transactions, gas_price) do
    total_gas = Enum.sum(Enum.map(transactions, & &1.gas_estimate))
    total_cost = total_gas * gas_price / 1_000_000_000

    per_tx_costs = Enum.map(transactions, fn tx ->
      cost = tx.gas_estimate * gas_price / 1_000_000_000

      %{
        index: tx.index,
        type: tx.type,
        gas: tx.gas_estimate,
        cost_eth: Float.round(cost, 8),
        pct_of_total: Float.round(tx.gas_estimate / max(total_gas, 1) * 100, 1)
      }
    end)

    %{
      total_gas: total_gas,
      total_cost_eth: total_cost,
      per_tx_costs: per_tx_costs,
      avg_gas_per_tx: if(length(transactions) > 0, do: div(total_gas, length(transactions)), else: 0)
    }
  end

  defp generate_optimizations(transactions, analysis, gas_price, level) do
    optimizations = []

    # 1. Timing optimization for low-urgency transactions
    low_urgency = Enum.filter(transactions, &(&1.urgency in ["low"]))
    optimizations = if length(low_urgency) > 0 do
      low_gas = Enum.sum(Enum.map(low_urgency, & &1.gas_estimate))
      savings = low_gas * gas_price * 0.3 / 1_000_000_000  # ~30% savings by waiting

      optimizations ++ [%{
        strategy: "timing_optimization",
        description: "Delay #{length(low_urgency)} low-urgency transaction(s) to off-peak hours (weekends, early morning UTC)",
        affected_transactions: Enum.map(low_urgency, & &1.index),
        estimated_savings_eth: Float.round(savings, 8),
        difficulty: "easy"
      }]
    else
      optimizations
    end

    # 2. Batching optimization for same-type transactions
    type_groups = Enum.group_by(transactions, & &1.type)
    optimizations = Enum.reduce(type_groups, optimizations, fn {type, txs}, acc ->
      if length(txs) > 1 do
        batch_savings = length(txs) * 5000 * gas_price / 1_000_000_000

        acc ++ [%{
          strategy: "transaction_batching",
          description: "Batch #{length(txs)} #{type} transactions using multicall or batch contract",
          affected_transactions: Enum.map(txs, & &1.index),
          estimated_savings_eth: Float.round(batch_savings, 8),
          difficulty: "moderate"
        }]
      else
        acc
      end
    end)

    # 3. Approve + Transfer optimization
    has_approve = Enum.any?(transactions, &(&1.type == "erc20_approve"))
    has_transfer = Enum.any?(transactions, &(&1.type == "erc20_transfer"))
    optimizations = if has_approve and has_transfer do
      savings = 20_000 * gas_price / 1_000_000_000

      optimizations ++ [%{
        strategy: "permit_pattern",
        description: "Use EIP-2612 Permit to combine approve+transfer into single transaction",
        estimated_savings_eth: Float.round(savings, 8),
        difficulty: "moderate"
      }]
    else
      optimizations
    end

    # 4. Aggressive: L2 migration suggestion
    optimizations = if level == "aggressive" and analysis.total_cost_eth > 0.005 do
      l2_savings = analysis.total_cost_eth * 0.95

      optimizations ++ [%{
        strategy: "l2_migration",
        description: "Execute on Layer 2 (Arbitrum, Optimism, Base) for ~95% cost reduction",
        estimated_savings_eth: Float.round(l2_savings, 8),
        difficulty: "complex",
        note: "Requires bridging assets to L2"
      }]
    else
      optimizations
    end

    # 5. EIP-1559 recommendation
    optimizations = optimizations ++ [%{
      strategy: "eip1559_pricing",
      description: "Use EIP-1559 fee parameters instead of legacy gas pricing for more predictable costs",
      estimated_savings_eth: Float.round(analysis.total_cost_eth * 0.05, 8),
      difficulty: "easy"
    }]

    optimizations
  end

  defp build_execution_plan(transactions, _optimizations, gas_price) do
    # Sort by urgency, then by gas cost (cheapest first within same urgency)
    urgency_order = %{"critical" => 0, "high" => 1, "medium" => 2, "low" => 3}

    transactions
    |> Enum.sort_by(fn tx ->
      {Map.get(urgency_order, tx.urgency, 2), tx.gas_estimate}
    end)
    |> Enum.map(fn tx ->
      cost = tx.gas_estimate * gas_price / 1_000_000_000

      %{
        order: tx.index,
        type: tx.type,
        urgency: tx.urgency,
        gas: tx.gas_estimate,
        cost_eth: Float.round(cost, 8),
        recommendation: timing_recommendation(tx.urgency)
      }
    end)
  end

  defp timing_recommendation("critical"), do: "Execute immediately with fast gas"
  defp timing_recommendation("high"), do: "Execute within current block window"
  defp timing_recommendation("medium"), do: "Execute at standard gas price, wait for moderate congestion"
  defp timing_recommendation("low"), do: "Wait for off-peak hours or gas price drop"
  defp timing_recommendation(_), do: "Execute at standard gas price"

  defp calculate_savings(optimizations, _total_gas, _gas_price) do
    optimizations
    |> Enum.map(&Map.get(&1, :estimated_savings_eth, 0))
    |> Enum.sum()
  end

  defp analyze_budget(_total_cost, _potential_savings, nil) do
    %{within_budget: true, remaining: 0.0, note: "No budget specified"}
  end

  defp analyze_budget(total_cost, potential_savings, budget) when is_number(budget) do
    optimized_cost = total_cost - potential_savings
    remaining = budget - optimized_cost

    %{
      within_budget: remaining >= 0,
      remaining: Float.round(max(remaining, 0) * 1.0, 8),
      budget: budget,
      cost_before_optimization: Float.round(total_cost * 1.0, 8),
      cost_after_optimization: Float.round(max(optimized_cost, 0) * 1.0, 8)
    }
  end

  defp l2_alternatives(total_gas, gas_price) do
    l1_cost = total_gas * gas_price / 1_000_000_000

    Enum.map(@l2_savings, fn {l2, factor} ->
      l2_cost = l1_cost * factor
      savings = l1_cost - l2_cost

      %{
        network: l2,
        estimated_cost_eth: Float.round(l2_cost, 8),
        savings_eth: Float.round(savings, 8),
        savings_pct: Float.round((1 - factor) * 100, 0)
      }
    end)
    |> Enum.sort_by(& &1.estimated_cost_eth)
  end

  defp parse_number(value, _default) when is_number(value), do: value * 1.0

  defp parse_number(value, default) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> default
    end
  end

  defp parse_number(_, default), do: default

  defp chain_id("mainnet"), do: 1
  defp chain_id("goerli"), do: 5
  defp chain_id("sepolia"), do: 11_155_111
  defp chain_id(_), do: 1

  defp get_field(map, key, default \\ nil) when is_atom(key) do
    Map.get(map, key) || Map.get(map, to_string(key)) || default
  end
end
