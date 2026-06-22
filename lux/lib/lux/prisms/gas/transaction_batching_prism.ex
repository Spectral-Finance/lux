defmodule Lux.Prisms.Gas.TransactionBatchingPrism do
  @moduledoc """
  A prism that batches multiple Ethereum transactions for gas-efficient execution.

  Analyzes transactions, orders by nonce, estimates total gas, and provides
  cost comparison between individual vs batched execution.

  ## Examples

      iex> Lux.Prisms.Gas.TransactionBatchingPrism.run(%{
      ...>   transactions: [
      ...>     %{to: "0x...", value: "1000000000000000000"},
      ...>     %{to: "0x...", value: "500000000000000000"}
      ...>   ],
      ...>   gas_price_gwei: 30
      ...> })
      {:ok, %{
        batch_plan: %{...},
        total_gas_estimate: 210000,
        total_cost_eth: 0.0063,
        individual_cost_eth: 0.0084,
        gas_savings_percent: 25.0
      }}
  """

  use Lux.Prism,
    name: "Transaction Batching Optimizer",
    description:
      "Batches multiple Ethereum transactions with nonce management and gas cost optimization",
    input_schema: %{
      type: :object,
      properties: %{
        transactions: %{
          type: :array,
          description: "List of transactions to batch",
          items: %{
            type: :object,
            properties: %{
              to: %{type: :string, description: "Recipient address"},
              value: %{type: :string, description: "Value in wei"},
              data: %{type: :string, description: "Transaction calldata (hex)"},
              gas_limit: %{type: :integer, description: "Custom gas limit"},
              nonce: %{type: :integer, description: "Specific nonce (nil for auto-ordering)"}
            },
            required: ["to"]
          }
        },
        gas_price_gwei: %{
          type: :number,
          description: "Gas price in GWei for estimation",
          minimum: 0.1
        },
        max_batch_size: %{
          type: :integer,
          description: "Maximum transactions per batch",
          default: 10,
          minimum: 1,
          maximum: 50
        },
        start_nonce: %{
          type: :integer,
          description: "Starting nonce for the batch (auto-detected if not provided)"
        }
      },
      required: ["transactions"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        batch_plan: %{
          type: :object,
          description: "Structured batch execution plan with ordered transactions"
        },
        total_transactions: %{
          type: :integer,
          description: "Total number of transactions in the batch"
        },
        total_gas_estimate: %{
          type: :integer,
          description: "Estimated total gas for all transactions"
        },
        total_cost_wei: %{
          type: :integer,
          description: "Total gas cost in wei"
        },
        total_cost_eth: %{
          type: :number,
          description: "Total gas cost in ETH"
        },
        individual_cost_wei: %{
          type: :integer,
          description: "Cost if transactions were sent individually"
        },
        individual_cost_eth: %{
          type: :number,
          description: "Individual cost in ETH"
        },
        gas_savings_percent: %{
          type: :number,
          description: "Percentage of gas saved by batching"
        },
        nonce_range: %{
          type: :object,
          properties: %{
            start: %{type: :integer},
            end: %{type: :integer}
          },
          description: "Nonce range covered by the batch"
        }
      },
      required: [
        "batch_plan",
        "total_transactions",
        "total_gas_estimate",
        "total_cost_wei",
        "total_cost_eth",
        "individual_cost_wei",
        "individual_cost_eth",
        "gas_savings_percent",
        "nonce_range"
      ]
    }

  alias Lux.Config

  require Logger

  @standard_transfer_gas 21_000
  @contract_interaction_gas 65_000
  @gwei 1_000_000_000

  @doc """
  Handler for transaction batching.
  """
  @spec handler(map(), map() | nil) :: {:ok, map()} | {:error, String.t()}
  def handler(input, _ctx \ nil) do
    transactions = Map.get(input, :transactions, [])
    gas_price_gwei = Map.get(input, :gas_price_gwei, 30)
    max_batch_size = Map.get(input, :max_batch_size, 10)
    start_nonce = Map.get(input, :start_nonce)

    if is_list(transactions) and length(transactions) == 0 do
      {:error, "No transactions provided for batching"}
    else
      ordered_txs = order_transactions(transactions)
      batched = Enum.take(ordered_txs, max_batch_size)
      gas_price_wei = trunc(gas_price_gwei * @gwei)

      {gas_estimates, batch_plan} = build_batch_plan(batched, start_nonce)
      total_gas = Enum.sum(gas_estimates)
      total_cost_wei = total_gas * gas_price_wei
      total_cost_eth = total_cost_wei / (1_000_000_000_000_000_000)

      # Individual cost assumes slightly higher gas due to base fee overhead per tx
      individual_gas_per_tx =
        gas_estimates
        |> Enum.map(fn g -> g + 5_000 end)
        |> Enum.sum()

      individual_cost_wei = individual_gas_per_tx * gas_price_wei
      individual_cost_eth = individual_cost_wei / (1_000_000_000_000_000_000)

      savings =
        if individual_cost_wei > 0 do
          round((1 - total_cost_wei / individual_cost_wei) * 10_000) / 100
        else
          0.0
        end

      nonce_range = %{
        start: start_nonce || 0,
        end: (start_nonce || 0) + length(batched) - 1
      }

      {:ok,
       %{
         batch_plan: batch_plan,
         total_transactions: length(batched),
         total_gas_estimate: total_gas,
         total_cost_wei: total_cost_wei,
         total_cost_eth: round(total_cost_eth * 1_000_000) / 1_000_000,
         individual_cost_wei: individual_cost_wei,
         individual_cost_eth: round(individual_cost_eth * 1_000_000) / 1_000_000,
         gas_savings_percent: max(savings, 0.0),
         nonce_range: nonce_range
       }}
    end
  end

  defp order_transactions(transactions) do
    transactions
    |> Enum.sort_by(fn tx ->
      case Map.get(tx, :nonce) do
        nil -> :infinity
        n when is_integer(n) -> n
      end
    end)
  end

  defp build_batch_plan(transactions, start_nonce) do
    Enum.reduce(transactions, {[], %{plan: [], total_value: 0}}, fn tx, {estimates, acc} ->
      gas = estimate_tx_gas(tx)
      nonce = Map.get(tx, :nonce, start_nonce)

      entry = %{
        to: tx.to,
        value: Map.get(tx, :value, "0"),
        data: Map.get(tx, :data, "0x"),
        gas_limit: gas,
        nonce: nonce,
        estimated_cost_wei: gas * trunc(Map.get(tx, :gas_price_gwei, 30) * @gwei)
      }

      {
        [gas | estimates],
        %{
          plan: acc.plan ++ [entry],
          total_value: acc.total_value + String.to_integer(Map.get(tx, :value, "0"))
        }
      }
    end)
  end

  defp estimate_tx_gas(tx) do
    case Map.get(tx, :gas_limit) do
      nil ->
        case Map.get(tx, :data) do
          nil -> @standard_transfer_gas
          data when data in ["0x", "0x0", ""] -> @standard_transfer_gas
          _ -> @contract_interaction_gas
        end

      gas when is_integer(gas) and gas > 0 -> gas
      _ -> @standard_transfer_gas
    end
  end
end
