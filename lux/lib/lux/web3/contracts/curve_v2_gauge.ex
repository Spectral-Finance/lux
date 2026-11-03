defmodule Lux.Web3.Contracts.CurveV2Gauge do
  @moduledoc """
  Curve Finance V2 Gauge contract.

  The gauge is the staking contract linked to a Curve pool (`CurveV2Pool.minter/0`
  returns the gauge address). LP token holders deposit into the gauge to earn CRV
  rewards, making this module the on-chain entry point for gauge staking and
  CRV rewards handling.

  Query functions (`balance_of/1`, `working_supply/0`, `reward_rate/0`,
  `earned/1`) are read-only `view` functions executed with `Ethers.call/2`.
  Staking actions (`deposit/2`, `withdraw/2`, `get_reward/1`) are executed
  with `Ethers.send_transaction/2`.

  ## Example

      iex> gauge = "0x522b139797aA4BC9a1e3782E52cF884c5b1d4338"
      iex> tx = CurveV2Gauge.earned("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
      iex> {:ok, crv} = Ethers.call(tx, to: gauge)
  """
  use Ethers.Contract,
    abi_file: "priv/web3/abis/CurveV2Gauge.abi.json"
end
