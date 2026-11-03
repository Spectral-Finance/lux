defmodule Lux.Web3.Curve do
  @moduledoc """
  Curve Finance integration for stablecoin management and optimal yield.

  This module family provides typed `Ethers.Contract` access to the Curve V2
  on-chain contracts and pure, deterministic decision helpers used to manage
  stablecoin liquidity positions.

  ## Modules

    * `Lux.Web3.Contracts.CurveV2Pool` - pool reads (`get_dy/3`, `balances/1`)
      and liquidity/swap writes (`exchange/4`, `add_liquidity/2`,
      `remove_liquidity/2`)
    * `Lux.Web3.Contracts.CurveV2Gauge` - gauge staking (`deposit/1`,
      `withdraw/1`) and CRV accrual (`earned/1`)
    * `Lux.Web3.Contracts.CurveV2CRV` - the CRV reward token (`balance_of/1`,
      `approve/2`, `transfer/2`)
    * `Lux.Web3.Curve.PoolAnalysis` - pool scoring, ranking and selection
    * `Lux.Web3.Curve.Slippage` - slippage and price-impact optimisation
    * `Lux.Web3.Curve.Rebalancer` - automated rebalancing plans
    * `Lux.Web3.Curve.Rewards` - CRV rewards claim optimisation
    * `Lux.Web3.Curve.PositionLedger` - atomic position accounting

  ## Example

      iex> pools = [
      ...>   %{
      ...>     address: "0xaaa",
      ...>     balances: [1_000_000, 1_000_000],
      ...>     virtual_price: 1_000_000_000_000_000_000,
      ...>     fee: 1_000_000,
      ...>     crv_reward_rate: 1_000_000_000_000_000_000
      ...>   },
      ...>   %{
      ...>     address: "0xbbb",
      ...>     balances: [9_000_000, 1_000_000],
      ...>     virtual_price: 1_000_000_000_000_000_000,
      ...>     fee: 4_000_000
      ...>   }
      ...> ]
      iex> {:ok, best} = Lux.Web3.Curve.PoolAnalysis.select_best(pools)
      iex> best.address
      "0xaaa"

  ## Examples

  See the module documentation of each submodule for runnable examples covering
  pool analysis, slippage protection, rebalancing and CRV reward claiming.
  """
end
