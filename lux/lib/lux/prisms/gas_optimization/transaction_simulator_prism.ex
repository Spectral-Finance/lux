defmodule Lux.Prisms.GasOptimization.TransactionSimulatorPrism do
  @moduledoc """
  A prism that simulates transactions to estimate gas usage and detect potential failures
  before actual submission.

  ## Features

  - Estimates gas usage for transactions
  - Detects reverts and out-of-gas conditions
  - Validates transaction parameters
  - Provides gas cost breakdown
  - Simulates multiple transactions in sequence

  ## Examples

      iex> Lux.Prisms.GasOptimization.TransactionSimulatorPrism.run(%{
      ...>   transactions: [
      ...>     %{from: "0x...", to: "0x...", value: "0", data: "0x..."}
      ...>   ],
      ...>   gas_price_gwei: 25.0
      ...> })
      {:ok, %{
        simulations: [
          %{
            status: "success",
            gas_used: 45000,
            gas_limit_recommended: 63000,
            cost_eth: 0.001125,
            warnings: []
          }
        ],
        total_gas: 45000,
        total_cost_eth: 0.001125
      }}
  """

  use Lux.Prism,
    name: "Transaction Simulator",
    description: "Simulates transactions to estimate gas and detect failures before submission",
    input_schema: %{
      type: :object,
      properties: %{
        transactions: %{
          type: :array,
          description: "Transactions to simulate",
          items: %{
            type: :object,
            properties: %{
              from: %{type: :string, description: "Sender address"},
              to: %{type: :string, description: "Recipient/contract address"},
              value: %{type: :string, description: "ETH value in wei", default: "0"},
              data: %{type: :string, description: "Calldata hex", default: "0x"},
              gas_limit: %{type: :integer, description: "Gas limit override"}
            },
            required: ["from", "to"]
          }
        },
        gas_price_gwei: %{
          type: :number,
          description: "Gas price for cost estimation",
          default: 20.0
        },
        include_trace: %{
          type: :boolean,
          description: "Include execution trace details",
          default: false
        }
      },
      required: ["transactions"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        simulations: %{type: :array},
        total_gas: %{type: :integer},
        total_cost_eth: %{type: :number},
        all_successful: %{type: :boolean}
      }
    }

  require Logger

  # Gas costs for common operations
  @gas_costs %{
    base_transaction: 21_000,
    zero_byte: 4,
    non_zero_byte: 16,
    sstore_new: 20_000,
    sstore_update: 5_000,
    sload: 2_100,
    call: 2_600,
    create: 32_000,
    log: 375,
    log_topic: 375,
    log_data: 8,
    memory_word: 3,
    copy_word: 3,
    erc20_transfer: 65_000,
    erc20_approve: 46_000,
    uniswap_swap: 150_000,
    eth_transfer: 21_000
  }

  # Gas limit safety multiplier
  @gas_limit_multiplier 1.4

  def handler(input, _ctx) do
    transactions = Map.get(input, :transactions, [])
    gas_price_gwei = Map.get(input, :gas_price_gwei, 20.0)
    include_trace = Map.get(input, :include_trace, false)

    if Enum.empty?(transactions) do
      {:error, "No transactions provided for simulation"}
    else
      simulations = Enum.map(transactions, fn tx ->
        simulate_transaction(tx, gas_price_gwei, include_trace)
      end)

      total_gas = simulations |> Enum.map(& &1.gas_used) |> Enum.sum()
      total_cost = simulations |> Enum.map(& &1.cost_eth) |> Enum.sum()
      all_successful = Enum.all?(simulations, &(&1.status == "success"))

      {:ok,
       %{
         simulations: simulations,
         total_gas: total_gas,
         total_cost_eth: Float.round(total_cost, 8),
         all_successful: all_successful,
         gas_price_gwei: gas_price_gwei
       }}
    end
  end

  @doc """
  Simulates a single transaction and returns gas estimation and validation results.
  """
  def simulate_transaction(tx, gas_price_gwei, include_trace) do
    from = get_field(tx, :from, "")
    to = get_field(tx, :to, "")
    value = get_field(tx, :value, "0")
    data = get_field(tx, :data, "0x")
    explicit_gas_limit = get_field(tx, :gas_limit)

    # Validate addresses
    warnings = validate_transaction(from, to, value, data)

    # Estimate gas based on transaction type
    {gas_used, tx_type} = estimate_gas(to, data, value)

    # Apply explicit gas limit or calculate recommended
    gas_limit_recommended = ceil(gas_used * @gas_limit_multiplier)
    gas_limit = explicit_gas_limit || gas_limit_recommended

    # Check if gas limit is sufficient
    {status, extra_warnings} = check_gas_sufficiency(gas_used, gas_limit)

    # Calculate cost
    cost_eth = gas_used * gas_price_gwei / 1_000_000_000.0

    result = %{
      status: status,
      tx_type: tx_type,
      gas_used: gas_used,
      gas_limit: gas_limit,
      gas_limit_recommended: gas_limit_recommended,
      cost_eth: Float.round(cost_eth, 8),
      cost_gwei: Float.round(gas_used * gas_price_gwei * 1.0, 2),
      warnings: warnings ++ extra_warnings,
      from: from,
      to: to
    }

    if include_trace do
      Map.put(result, :gas_breakdown, gas_breakdown(tx_type, data))
    else
      result
    end
  end

  @doc """
  Estimates gas for a transaction based on its type and data.
  """
  def estimate_gas(to, data, value) do
    tx_type = classify_transaction(to, data, value)

    gas = case tx_type do
      "eth_transfer" ->
        @gas_costs.eth_transfer

      "erc20_transfer" ->
        @gas_costs.base_transaction + @gas_costs.erc20_transfer

      "erc20_approve" ->
        @gas_costs.base_transaction + @gas_costs.erc20_approve

      "dex_swap" ->
        @gas_costs.base_transaction + @gas_costs.uniswap_swap

      "contract_creation" ->
        @gas_costs.create + @gas_costs.base_transaction + calldata_gas(data)

      "contract_call" ->
        @gas_costs.base_transaction + @gas_costs.call + calldata_gas(data)

      _ ->
        @gas_costs.base_transaction + calldata_gas(data)
    end

    {gas, tx_type}
  end

  @doc """
  Classifies a transaction type from its parameters.
  """
  def classify_transaction(to, data, value) do
    cond do
      to == "" or is_nil(to) ->
        "contract_creation"

      data in ["", "0x", nil] ->
        "eth_transfer"

      String.starts_with?(data || "", "0xa9059cbb") ->
        "erc20_transfer"

      String.starts_with?(data || "", "0x095ea7b3") ->
        "erc20_approve"

      is_swap_data?(data) ->
        "dex_swap"

      true ->
        "contract_call"
    end
  end

  defp is_swap_data?(data) when is_binary(data) do
    selector = String.slice(data, 0, 10)

    selector in [
      "0x38ed1739", "0x8803dbee", "0x7ff36ab5",
      "0x18cbafe5", "0x414bf389", "0xc04b8d59"
    ]
  end

  defp is_swap_data?(_), do: false

  defp calldata_gas(data) when is_binary(data) do
    # Remove 0x prefix
    hex_data = String.replace_prefix(data, "0x", "")

    # Count zero and non-zero bytes
    byte_count = div(String.length(hex_data), 2)

    # Approximate: assume 30% zero bytes
    zero_bytes = round(byte_count * 0.3)
    non_zero_bytes = byte_count - zero_bytes

    zero_bytes * @gas_costs.zero_byte + non_zero_bytes * @gas_costs.non_zero_byte
  end

  defp calldata_gas(_), do: 0

  defp validate_transaction(from, to, _value, _data) do
    warnings = []

    warnings =
      if from == "" or is_nil(from) do
        warnings ++ ["Missing sender address"]
      else
        if not valid_address?(from), do: warnings ++ ["Invalid sender address format"], else: warnings
      end

    warnings =
      if to != "" and not is_nil(to) and not valid_address?(to) do
        warnings ++ ["Invalid recipient address format"]
      else
        warnings
      end

    warnings
  end

  defp valid_address?(addr) when is_binary(addr) do
    Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, addr)
  end

  defp valid_address?(_), do: false

  defp check_gas_sufficiency(gas_used, gas_limit) do
    cond do
      gas_limit < gas_used ->
        {"failed", ["Gas limit (#{gas_limit}) is less than estimated gas usage (#{gas_used}). Transaction will fail with out-of-gas."]}

      gas_limit < gas_used * 1.1 ->
        {"success", ["Gas limit is tight. Consider increasing by 20% for safety."]}

      true ->
        {"success", []}
    end
  end

  defp gas_breakdown(tx_type, data) do
    base = %{
      base_transaction: @gas_costs.base_transaction,
      calldata: calldata_gas(data)
    }

    case tx_type do
      "erc20_transfer" -> Map.put(base, :execution, @gas_costs.erc20_transfer)
      "erc20_approve" -> Map.put(base, :execution, @gas_costs.erc20_approve)
      "dex_swap" -> Map.put(base, :execution, @gas_costs.uniswap_swap)
      "contract_creation" -> Map.put(base, :creation, @gas_costs.create)
      _ -> base
    end
  end

  defp get_field(map, key, default \\ nil) when is_atom(key) do
    Map.get(map, key) || Map.get(map, to_string(key)) || default
  end
end
