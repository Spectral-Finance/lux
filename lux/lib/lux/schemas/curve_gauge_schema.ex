defmodule Lux.Schemas.CurveGaugeSchema do
  @moduledoc """
  Schema definition for Curve Finance liquidity gauge staking and boost tracking.
  """

  @schema %{
    type: :object,
    properties: %{
      gauge_address: %{type: :string, pattern: "^0x[a-fA-F0-9]{40}$"},
      pool_id: %{type: :string},
      staked_balance: %{type: :string, description: "Raw staked LP token amount"},
      working_balance: %{type: :string, description: "veCRV-weighted working balance"},
      boost_multiplier: %{type: :number, minimum: 1.0, maximum: 2.5},
      claimable_crv: %{type: :string, description: "Accumulated unharvested CRV tokens"},
      gauge_weight: %{type: :number, description: "Relative DAO gauge weight determining emissions"}
    },
    required: ["gauge_address", "pool_id", "staked_balance", "boost_multiplier"]
  }

  def schema, do: @schema
end
