defmodule Lux.Web3.Transaction do
  @moduledoc """
  Transaction building, signing, and broadcasting for EVM chains.

  Uses ex_secp256k1 for signing and JSON-RPC for broadcasting.
  Supports EIP-1559 fee markets and legacy transactions.
  """

  @typedoc """
  Transaction parameters.
  """
  @type params :: %{
        optional(:to) => String.t(),
        optional(:value) => integer(),
        optional(:data) => String.t(),
        optional(:gas_limit) => integer(),
        optional(:gas_price) => integer(),
        optional(:max_fee_per_gas) => integer(),
        optional(:max_priority_fee_per_gas) => integer(),
        optional(:nonce) => integer() | nil,
        optional(:chain_id) => integer(),
        optional(:rpc_url) => String.t(),
        optional(:type) => :eip1559 | :legacy
      }
