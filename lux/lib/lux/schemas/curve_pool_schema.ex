defmodule Lux.Schemas.CurvePoolSchema do
  @moduledoc """
  Schema definition for Curve Finance stablecoin liquidity pools.
  """

  @schema %{
    type: :object,
    properties: %{
      pool_id: %{type: :string, description: "Curve pool identifier, e.g. 3pool, crvusd-usdc"},
      pool_address: %{type: :string, pattern: "^0x[a-fA-F0-9]{40}$"},
      lp_token_address: %{type: :string, pattern: "^0x[a-fA-F0-9]{40}$"},
      coins: %{
        type: :array,
        items: %{
          type: :object,
          properties: %{
            symbol: %{type: :string},
            address: %{type: :string},
            decimals: %{type: :integer},
            balance: %{type: :string}
          },
          required: ["symbol", "address", "decimals"]
        }
      },
      virtual_price: %{type: :string, description: "Normalized invariant virtual price in 1e18 wei"},
      a_parameter: %{type: :integer, description: "Amplification coefficient parameter (A)"},
      fee_bps: %{type: :integer, description: "Swap fee in basis points"},
      base_apy: %{type: :number, description: "Trading fee annualized return percentage"},
      reward_apy: %{type: :number, description: "CRV and incentive token annualized return"}
    },
    required: ["pool_id", "pool_address", "virtual_price", "a_parameter"]
  }

  def schema, do: @schema
end
