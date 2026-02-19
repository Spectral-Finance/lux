defmodule Lux.MultiChain.DataModel do
  @moduledoc """
  Unified data models for normalized multi-chain blockchain data.

  These structs provide a chain-agnostic representation of common blockchain
  entities (blocks, transactions, events, tokens, balances) that can be
  populated from any supported EVM chain.

  All models include a `:chain` field identifying the source chain, enabling
  cross-chain queries and comparisons.
  """

  defmodule Block do
    @moduledoc """
    Normalized block data across EVM chains.
    """
    @type t :: %__MODULE__{
            chain: atom(),
            chain_id: pos_integer(),
            number: non_neg_integer(),
            hash: String.t(),
            parent_hash: String.t(),
            timestamp: DateTime.t(),
            miner: String.t(),
            gas_used: non_neg_integer(),
            gas_limit: non_neg_integer(),
            base_fee_per_gas: non_neg_integer() | nil,
            transaction_count: non_neg_integer(),
            size: non_neg_integer() | nil
          }

    defstruct [
      :chain,
      :chain_id,
      :number,
      :hash,
      :parent_hash,
      :timestamp,
      :miner,
      :gas_used,
      :gas_limit,
      :base_fee_per_gas,
      :transaction_count,
      :size
    ]
  end

  defmodule Transaction do
    @moduledoc """
    Normalized transaction data across EVM chains.
    """
    @type t :: %__MODULE__{
            chain: atom(),
            chain_id: pos_integer(),
            hash: String.t(),
            block_number: non_neg_integer(),
            block_hash: String.t() | nil,
            from: String.t(),
            to: String.t() | nil,
            value: String.t(),
            value_decimal: float(),
            gas: non_neg_integer(),
            gas_price: non_neg_integer() | nil,
            gas_used: non_neg_integer() | nil,
            nonce: non_neg_integer(),
            input: String.t(),
            status: :success | :failure | :pending,
            timestamp: DateTime.t() | nil,
            transaction_index: non_neg_integer() | nil
          }

    defstruct [
      :chain,
      :chain_id,
      :hash,
      :block_number,
      :block_hash,
      :from,
      :to,
      :value,
      :gas,
      :gas_price,
      :gas_used,
      :nonce,
      :input,
      :timestamp,
      :transaction_index,
      value_decimal: 0.0,
      status: :pending
    ]
  end

  defmodule Event do
    @moduledoc """
    Normalized smart contract event/log data across EVM chains.
    """
    @type t :: %__MODULE__{
            chain: atom(),
            chain_id: pos_integer(),
            address: String.t(),
            topics: [String.t()],
            data: String.t(),
            block_number: non_neg_integer(),
            block_hash: String.t() | nil,
            transaction_hash: String.t(),
            transaction_index: non_neg_integer() | nil,
            log_index: non_neg_integer(),
            removed: boolean(),
            event_name: String.t() | nil,
            decoded_data: map() | nil,
            timestamp: DateTime.t() | nil
          }

    defstruct [
      :chain,
      :chain_id,
      :address,
      :data,
      :block_number,
      :block_hash,
      :transaction_hash,
      :transaction_index,
      :log_index,
      :event_name,
      :decoded_data,
      :timestamp,
      topics: [],
      removed: false
    ]
  end

  defmodule TokenBalance do
    @moduledoc """
    Normalized token balance data across EVM chains.
    """
    @type t :: %__MODULE__{
            chain: atom(),
            chain_id: pos_integer(),
            address: String.t(),
            contract_address: String.t() | nil,
            token_name: String.t() | nil,
            token_symbol: String.t() | nil,
            token_decimals: non_neg_integer(),
            balance_raw: String.t(),
            balance_formatted: float(),
            token_type: :native | :erc20 | :erc721 | :erc1155,
            last_updated: DateTime.t() | nil
          }

    defstruct [
      :chain,
      :chain_id,
      :address,
      :contract_address,
      :token_name,
      :token_symbol,
      :balance_raw,
      :last_updated,
      token_decimals: 18,
      balance_formatted: 0.0,
      token_type: :native
    ]
  end

  defmodule GasPrice do
    @moduledoc """
    Normalized gas price data across EVM chains.
    """
    @type t :: %__MODULE__{
            chain: atom(),
            chain_id: pos_integer(),
            safe_gas_price: float(),
            propose_gas_price: float(),
            fast_gas_price: float(),
            base_fee: float() | nil,
            unit: String.t(),
            timestamp: DateTime.t()
          }

    defstruct [
      :chain,
      :chain_id,
      :safe_gas_price,
      :propose_gas_price,
      :fast_gas_price,
      :base_fee,
      :timestamp,
      unit: "gwei"
    ]
  end
end
