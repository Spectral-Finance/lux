defmodule Lux.Web3.Curve.Rewards do
  @moduledoc """
  CRV rewards handling for Curve gauge positions.

  The gauge accrues CRV rewards that must be claimed (`get_reward`) at the right
  moment. Claiming costs gas, so `should_claim?/3` only recommends a claim when
  the claimable value strictly exceeds the gas cost. Equality is treated as
  "skip" to honour a strict half-open threshold.
  """

  @doc """
  Decides whether claiming accrued CRV is economically worthwhile.

  ## Arguments

    * `claimable_crv` - whole CRV tokens available to claim (non-negative integer)
    * `crv_price_wei` - price of a single CRV token in wei (non-negative integer)
    * `gas_cost_wei` - estimated gas cost of the claim transaction in wei

  Returns `{:ok, %{value:, gas_cost:, net:, decision: :claim | :skip}}` or a typed
  `{:error, :invalid_reward_input}`.
  """
  @spec should_claim?(term(), term(), term()) :: {:ok, map()} | {:error, atom()}
  def should_claim?(claimable_crv, crv_price_wei, gas_cost_wei)
      when is_integer(claimable_crv) and claimable_crv >= 0 and is_integer(crv_price_wei) and
             crv_price_wei >= 0 and is_integer(gas_cost_wei) and gas_cost_wei >= 0 do
    value = claimable_crv * crv_price_wei
    decision = if value > gas_cost_wei, do: :claim, else: :skip

    {:ok,
     %{
       value: value,
       gas_cost: gas_cost_wei,
       net: value - gas_cost_wei,
       decision: decision
     }}
  end

  def should_claim?(_claimable_crv, _crv_price_wei, _gas_cost_wei),
    do: {:error, :invalid_reward_input}
end
