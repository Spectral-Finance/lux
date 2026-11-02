defmodule Lux.Web3.WalletInfrastructure.GasManager do
  @moduledoc """
  Dynamic gas price estimation, EIP-1559 fee calculation across L1 and L2 chains,
  and transaction speed-up fee replacement calculators.
  """

  @gwei 1_000_000_000

  @chain_base_fees %{
    1 => 25 * @gwei,        # Ethereum Mainnet
    11155111 => 2 * @gwei,  # Sepolia
    42161 => div(@gwei, 10),# Arbitrum One (0.1 Gwei)
    10 => div(@gwei, 20),   # Optimism (0.05 Gwei)
    8453 => div(@gwei, 20), # Base (0.05 Gwei)
    137 => 40 * @gwei,      # Polygon PoS
    56 => 3 * @gwei         # BSC
  }

  @type fee_tier :: %{
          max_fee_per_gas: non_neg_integer(),
          max_priority_fee_per_gas: non_neg_integer(),
          estimated_total_fee_eth: float()
        }

  @type gas_estimate_report :: %{
          chain_id: non_neg_integer(),
          gas_limit: non_neg_integer(),
          slow: fee_tier(),
          standard: fee_tier(),
          fast: fee_tier()
        }

  @doc """
  Estimates EIP-1559 gas fee tiers (slow, standard, fast) for a target chain and gas limit.
  """
  @spec estimate_gas_tiers(non_neg_integer(), non_neg_integer()) :: gas_estimate_report()
  def estimate_gas_tiers(chain_id, gas_limit \\ 21_000) do
    base_fee = Map.get(@chain_base_fees, chain_id, 20 * @gwei)

    slow_tip = div(base_fee, 10)
    std_tip = div(base_fee, 5)
    fast_tip = div(base_fee, 2)

    %{
      chain_id: chain_id,
      gas_limit: gas_limit,
      slow: build_tier(base_fee, slow_tip, gas_limit),
      standard: build_tier(base_fee, std_tip, gas_limit),
      fast: build_tier(round(base_fee * 1.25), fast_tip, gas_limit)
    }
  end

  @doc """
  Calculates replacement fee for speeding up a stuck pending transaction (+15% tip rule).
  """
  @spec calculate_speed_up_fee(non_neg_integer(), non_neg_integer()) :: %{
          max_fee_per_gas: non_neg_integer(),
          max_priority_fee_per_gas: non_neg_integer()
        }
  def calculate_speed_up_fee(current_max_fee, current_priority_fee) do
    new_max = round(current_max_fee * 1.15)
    new_priority = round(current_priority_fee * 1.15)

    %{
      max_fee_per_gas: new_max,
      max_priority_fee_per_gas: new_priority
    }
  end

  @doc """
  Estimates gas limit based on transaction payload characteristics.
  """
  @spec estimate_gas_limit(String.t(), binary() | String.t()) :: non_neg_integer()
  def estimate_gas_limit(_to_address, data) do
    clean_data = String.trim_leading(to_string(data), "0x")

    cond do
      clean_data == "" -> 21_000 # Simple native transfer
      String.starts_with?(clean_data, "a9059cbb") -> 65_000 # ERC-20 transfer(address,uint256)
      String.starts_with?(clean_data, "095ea7b3") -> 50_000 # ERC-20 approve(address,uint256)
      true -> 250_000 # Complex contract interaction
    end
  end

  defp build_tier(base_fee, tip, gas_limit) do
    max_fee = base_fee + tip
    total_wei = max_fee * gas_limit
    total_eth = Float.round(total_wei / 1_000_000_000_000_000_000.0, 6)

    %{
      max_fee_per_gas: max_fee,
      max_priority_fee_per_gas: tip,
      estimated_total_fee_eth: total_eth
    }
  end
end
