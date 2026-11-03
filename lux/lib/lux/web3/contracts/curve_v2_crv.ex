defmodule Lux.Web3.Contracts.CurveV2CRV do
  @moduledoc """
  Curve Finance CRV token contract (ERC-20 subset).

  CRV is Curve's reward and governance token. This module supports CRV rewards
  handling: checking a holder's CRV balance, allowance for the reward
  distributor/gauge, and building `transfer`/`approve` transactions for
  claiming or moving rewards.

  Query functions (`balance_of/1`, `allowance/2`, `symbol/0`, `decimals/0`,
  `total_supply/0`) are read-only `view` functions executed with `Ethers.call/2`.
  State-changing functions (`transfer/3`, `approve/3`) are executed with
  `Ethers.send_transaction/2`.

  ## Example

      iex> crv = "0xD533a949740bb3306d119CC777fa900bA034cd52"
      iex> tx = CurveV2CRV.balance_of("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
      iex> {:ok, crv_balance} = Ethers.call(tx, to: crv)
  """
  use Ethers.Contract,
    abi_file: "priv/web3/abis/CurveV2CRV.abi.json"
end
