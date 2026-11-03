defmodule Lux.Web3.Contracts.CurveV2Pool do
  @moduledoc """
  Curve Finance V2 Plain Pool contract.

  Typed access to a Curve V2 stablecoin pool (e.g. the 3pool: DAI/USDC/USDT).
  This module supports stablecoin pool position management, slippage-aware swaps
  through `get_dy/3`, and gauge linkage through `minter/0` (the minter address is
  the pool's Curve gauge contract).

  It follows the same `use Ethers.Contract` pattern as
  `Lux.Web3.Contracts.AgenticCompany`. All query functions are read-only
  `view` functions and are executed with `Ethers.call/2`; state-changing
  functions (`exchange/4`, `add_liquidity/2`, `remove_liquidity/2`) are executed
  with `Ethers.send_transaction/2`.

  ## Example

      iex> pool = "0xcE4933736166e591F6149750aB95a91578295e49"
      iex> tx = CurveV2Pool.get_dy(0, 1, 1_000_000_000_000_000_000)
      iex> {:ok, dy} = Ethers.call(tx, to: pool, from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
  """
  use Ethers.Contract,
    abi_file: "priv/web3/abis/CurveV2Pool.abi.json"
end
