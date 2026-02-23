defmodule Lux.Lenses.PancakeSwap.PancakeSwapPoolInfoLens do
  @moduledoc """
  A lens for fetching PancakeSwap pool analytics and APY information.

  Reads on-chain pool state and fetches APY data from PancakeSwap's public API.
  Useful for selecting the highest-yield farms and monitoring pool health.

  ## Example

      iex> Lux.Lenses.PancakeSwap.PancakeSwapPoolInfoLens.focus(%{
      ...>   lp_token_address: "0x0eD7e52944161450477ee417DE9Cd3a859b14fD0"
      ...> }, %{agent: %{name: "YieldAgent"}})
      {:ok, %{
        lp_token_address: "0x0eD7e52944161450477ee417DE9Cd3a859b14fD0",
        token0_address: "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
        token1_address: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
        reserve0: "4500000000000000000000000",
        reserve1: "15000000000000000000000",
        total_supply: "8200000000000000000000",
        tvl_usd: 12400000.0,
        apy_base: 0.52,
        apy_cake: 18.4,
        apy_total: 18.92,
        pair_name: "CAKE-BNB LP"
      }}
  """

  use Lux.Lens,
    name: "PancakeSwap Pool Info",
    description: "Fetches PancakeSwap pool reserves, TVL, and APY data for yield optimization",
    schema: %{
      type: :object,
      properties: %{
        lp_token_address: %{
          type: :string,
          description: "PancakeSwap LP token / pair contract address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        factory_address: %{
          type: :string,
          description: "PancakeSwap Factory V2 address (defaults to BSC mainnet)",
          default: "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"
        }
      },
      required: ["lp_token_address"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @default_rpc "https://bsc-dataseed.binance.org"

  @impl true
  def focus(%{lp_token_address: lp_address} = _input, agent) do
    agent_name = get_in(agent, [:agent, :name]) || "Unknown"
    Logger.info("Agent #{agent_name} fetching PancakeSwap pool info for #{lp_address}")

    rpc_url = get_rpc_url()

    with {:ok, result} <- fetch_pool_info(rpc_url, lp_address) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_rpc_url do
    case Config.get(:pancakeswap_rpc_url) do
      nil -> System.get_env("PANCAKESWAP_RPC_URL") || @default_rpc
      url -> url
    end
  rescue
    _ -> System.get_env("PANCAKESWAP_RPC_URL") || @default_rpc
  end

  defp fetch_pool_info(rpc_url, lp_address) do
    result =
      python variables: %{rpc_url: rpc_url, lp_token_address: lp_address} do
        ~PY"""
        from web3 import Web3
        import urllib.request
        import json

        PAIR_ABI = [
            {"name": "getReserves", "type": "function", "inputs": [],
             "outputs": [
                 {"name": "_reserve0", "type": "uint112"},
                 {"name": "_reserve1", "type": "uint112"},
                 {"name": "_blockTimestampLast", "type": "uint32"}
             ]},
            {"name": "token0", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "address"}]},
            {"name": "token1", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "address"}]},
            {"name": "totalSupply", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        ERC20_ABI = [
            {"name": "symbol", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "string"}]},
            {"name": "decimals", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint8"}]}
        ]

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            lp_addr = Web3.to_checksum_address(lp_token_address)
            pair = w3.eth.contract(address=lp_addr, abi=PAIR_ABI)

            token0 = pair.functions.token0().call()
            token1 = pair.functions.token1().call()
            reserves = pair.functions.getReserves().call()
            total_supply = pair.functions.totalSupply().call()

            # Get token symbols
            try:
                tok0 = w3.eth.contract(address=token0, abi=ERC20_ABI)
                tok1 = w3.eth.contract(address=token1, abi=ERC20_ABI)
                sym0 = tok0.functions.symbol().call()
                sym1 = tok1.functions.symbol().call()
                pair_name = f"{sym0}-{sym1} LP"
            except Exception:
                sym0 = sym1 = ""
                pair_name = "Unknown LP"

            # Fetch APY from PancakeSwap API
            apy_base = 0.0
            apy_cake = 0.0
            tvl_usd = 0.0
            try:
                url = "https://farms.pancake.run/api/v2/farms"
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=10) as resp:
                    data = json.loads(resp.read())
                    for farm in data.get("data", {}).get("farmsWithPrices", []):
                        if farm.get("lpAddress", "").lower() == lp_token_address.lower():
                            apy_base = float(farm.get("lpApr", 0) or 0)
                            apy_cake = float(farm.get("cakeApr", 0) or 0)
                            tvl_usd = float(farm.get("liquidity", 0) or 0)
                            break
            except Exception:
                pass

            {
                "lp_token_address": lp_token_address,
                "token0_address": token0,
                "token1_address": token1,
                "token0_symbol": sym0,
                "token1_symbol": sym1,
                "reserve0": str(reserves[0]),
                "reserve1": str(reserves[1]),
                "total_supply": str(total_supply),
                "tvl_usd": tvl_usd,
                "apy_base": round(apy_base, 4),
                "apy_cake": round(apy_cake, 4),
                "apy_total": round(apy_base + apy_cake, 4),
                "pair_name": pair_name
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, %{
        lp_token_address: result["lp_token_address"],
        token0_address: result["token0_address"],
        token1_address: result["token1_address"],
        token0_symbol: result["token0_symbol"],
        token1_symbol: result["token1_symbol"],
        reserve0: result["reserve0"],
        reserve1: result["reserve1"],
        total_supply: result["total_supply"],
        tvl_usd: result["tvl_usd"],
        apy_base: result["apy_base"],
        apy_cake: result["apy_cake"],
        apy_total: result["apy_total"],
        pair_name: result["pair_name"]
      }}
    end
  end
end
