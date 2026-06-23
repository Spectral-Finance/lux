defmodule Lux.Web3.Gas.Types do
  @moduledoc """
  Shared types and schemas for gas optimization and transaction management.
  """

  @typedoc "EIP-1559 fee tier recommendation."
  @type fee_recommendation :: %__MODULE__{
          slow: %{max_fee_per_gas: integer(), max_priority_fee_per_gas: integer()},
          standard: %{max_fee_per_gas: integer(), max_priority_fee_per_gas: integer()},
          fast: %{max_fee_per_gas: integer(), max_priority_fee_per_gas: integer()},
          base_fee: integer(),
          suggested_tip: integer(),
          timestamp: DateTime.t()
        }

  @type t :: %__MODULE__{
          slow: map(),
          standard: map(),
          fast: map(),
          base_fee: integer(),
          suggested_tip: integer(),
          timestamp: DateTime.t()
        }

  defstruct slow: nil,
            standard: nil,
            fast: nil,
            base_fee: 0,
            suggested_tip: 0,
            timestamp: nil

  defmodule BatchPlan do
    @moduledoc "Represents a plan for batching multiple transactions together."
    @type t :: %__MODULE__{
            id: String.t(),
            transactions: [map()],
            nonce_start: integer(),
            estimated_total_gas: integer(),
            estimated_total_cost_eth: float(),
            created_at: DateTime.t()
          }
    defstruct id: nil, transactions: [], nonce_start: 0, estimated_total_gas: 0, estimated_total_cost_eth: 0.0, created_at: nil
  end

  defmodule Replacement do
    @moduledoc "Represents a transaction replacement (EIP-1559 or legacy)."
    @type replacement_type :: :speed_up | :cancel
    @type t :: %__MODULE__{
            original_tx_hash: String.t(),
            replacement_type: replacement_type(),
            new_nonce: integer(),
            new_max_fee_per_gas: integer(),
            new_max_priority_fee_per_gas: integer(),
            new_gas_price: integer() | nil,
            signed_tx_hex: String.t() | nil,
            created_at: DateTime.t()
          }
    defstruct original_tx_hash: nil, replacement_type: :speed_up, new_nonce: 0, new_max_fee_per_gas: 0, new_max_priority_fee_per_gas: 0, new_gas_price: nil, signed_tx_hex: nil, created_at: nil
  end

  defmodule MEVAnalysis do
    @moduledoc "Analysis of MEV (Miner Extractable Value) risks for a transaction."
    @type risk_level :: :low | :medium | :high
    @type t :: %__MODULE__{
            risk_level: risk_level(),
            is_front_running_risk: boolean(),
            is_sandwich_attack_risk: boolean(),
            recommended_private_relay: boolean(),
            suggestions: [String.t()]
          }
    defstruct risk_level: :low, is_front_running_risk: false, is_sandwich_attack_risk: false, recommended_private_relay: false, suggestions: []
  end

  defmodule SimulationResult do
    @moduledoc "Result of simulating a transaction before sending it on-chain."
    @type t :: %__MODULE__{
            success: boolean(),
            reverted: boolean(),
            revert_reason: String.t() | nil,
            estimated_gas: integer(),
            gas_used: integer() | nil,
            logs: [map()],
            state_changes: [map()]
          }
    defstruct success: true, reverted: false, revert_reason: nil, estimated_gas: 0, gas_used: nil, logs: [], state_changes: []
  end

  defmodule CostReport do
    @moduledoc "Report summarizing gas costs over a period."
    @type t :: %__MODULE__{
            period: String.t(),
            total_transactions: integer(),
            total_gas_used: integer(),
            total_cost_wei: integer(),
            total_cost_eth: float(),
            average_gas_price: integer(),
            average_cost_per_tx_eth: float(),
            savings_from_optimization: float(),
            breakdown_by_type: [map()]
          }
    defstruct period: "", total_transactions: 0, total_gas_used: 0, total_cost_wei: 0, total_cost_eth: 0.0, average_gas_price: 0, average_cost_per_tx_eth: 0.0, savings_from_optimization: 0.0, breakdown_by_type: []
  end

  defmodule GasTokenConfig do
    @moduledoc "Configuration for paying gas fees with an ERC-20 token."
    @type t :: %__MODULE__{
            enabled: boolean(),
            token_address: String.t() | nil,
            token_symbol: String.t() | nil,
            approval_required: boolean()
          }
    defstruct enabled: false, token_address: nil, token_symbol: nil, approval_required: false
  end
end
