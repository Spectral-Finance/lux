defmodule Lux.Lenses.Curve.CurvePoolInfoLens do
  @moduledoc """
  A lens for fetching Curve Finance pool analytics and yield information.

  Reads on-chain pool state including TVL, token balances, virtual price,
  pool APY via the Curve API, and fee rates. Useful for pool selection
  and rebalancing decisions.

  ## Example

      iex> Lux.Lenses.Curve.CurvePoolInfoLens.focus(%{
      ...>   pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
      ...> }, %{agent: %{name: "YieldAgent"}})
      {:ok, %{
        pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
        virtual_price: "1002345678901234567",
        balances: ["45000000000000000000000000", "47000000000", "43000000000"],
        fee_bps: 4,
        admin_fee_bps: 50,
        apy_base: 0.32,
        apy_reward: 2.14,
        apy_total: 2.46,
        tvl_usd: 135000000.0,
        pool_name: "3pool"
      }}
  """

  use Lux.Lens,
    name: "Curve Pool Info",
    description: "Fetches Curve pool analytics: virtual price, balances, TVL, and APY",
    schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Curve pool contract address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        rpc_url: %{
          type: :string,
          description: "Ethereum JSON-RPC endpoint URL (optional, uses config default)"
        }
      },
      required: ["pool_address"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @impl true
  def focus(%{pool_address: pool_address} = input, agent) do
    agent_name = get_in(agent, [:agent, :name]) || "Unknown"
    Logger.info("Agent #{agent_name} fetching Curve pool info for #{pool_address}")

    rpc_url = Map.get(input, :rpc_url) || get_rpc_url()

    with {:ok, result} <- fetch_pool_info(rpc_url, pool_address) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_rpc_url do
    case Config.get(:curve_rpc_url) do
      nil -> System.get_env("CURVE_RPC_URL") || "https://eth.llamarpc.com"
      url -> url
    end
  rescue
    _ -> System.get_env("CURVE_RPC_URL") || "https://eth.llamarpc.com"
  end

  defp fetch_pool_info(rpc_url, pool_address) do
    result =
      python variables: %{rpc_url: rpc_url, pool_address: pool_address} do
        ~PY"""
        from web3 import Web3
        import urllib.request
        import json
        import re

        POOL_ABI = [
            {"name": "get_virtual_price", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "balances", "type": "function",
             "inputs": [{"name": "i", "type": "uint256"}],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "fee", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "admin_fee", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "A", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "coins", "type": "function",
             "inputs": [{"name": "i", "type": "uint256"}],
             "outputs": [{"name": "", "type": "address"}]}
        ]

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            pool_addr = Web3.to_checksum_address(pool_address)
            pool = w3.eth.contract(address=pool_addr, abi=POOL_ABI)

            # Read on-chain state
            virtual_price = pool.functions.get_virtual_price().call()
            fee = pool.functions.fee().call()
            admin_fee = pool.functions.admin_fee().call()
            amplification = pool.functions.A().call()

            # Read balances (try up to 4 tokens)
            balances = []
            coin_addresses = []
            for i in range(4):
                try:
                    bal = pool.functions.balances(i).call()
                    balances.append(str(bal))
                    try:
                        coin = pool.functions.coins(i).call()
                        coin_addresses.append(coin)
                    except Exception:
                        coin_addresses.append("")
                except Exception:
                    break

            # Fetch APY from Curve API
            apy_base = 0.0
            apy_reward = 0.0
            pool_name = ""
            tvl_usd = 0.0
            try:
                url = "https://api.curve.fi/api/getPools/ethereum/main"
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=10) as resp:
                    data = json.loads(resp.read())
                    for p in data.get("data", {}).get("poolData", []):
                        if p.get("address", "").lower() == pool_address.lower():
                            apy_base = float(p.get("gaugeCrvApy", [0])[0] if p.get("gaugeCrvApy") else 0)
                            apy_reward = float(p.get("gaugeRewards", [{}])[0].get("apy", 0) if p.get("gaugeRewards") else 0)
                            pool_name = p.get("name", "")
                            tvl_usd = float(p.get("usdTotal", 0))
                            break
            except Exception:
                pass

            {
                "pool_address": pool_address,
                "virtual_price": str(virtual_price),
                "balances": balances,
                "coin_addresses": coin_addresses,
                "fee_bps": fee // 10**6,
                "admin_fee_bps": admin_fee // 10**6,
                "amplification": amplification,
                "apy_base": apy_base,
                "apy_reward": apy_reward,
                "apy_total": round(apy_base + apy_reward, 4),
                "tvl_usd": tvl_usd,
                "pool_name": pool_name
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, %{
        pool_address: result["pool_address"],
        virtual_price: result["virtual_price"],
        balances: result["balances"],
        coin_addresses: result["coin_addresses"],
        fee_bps: result["fee_bps"],
        admin_fee_bps: result["admin_fee_bps"],
        amplification: result["amplification"],
        apy_base: result["apy_base"],
        apy_reward: result["apy_reward"],
        apy_total: result["apy_total"],
        tvl_usd: result["tvl_usd"],
        pool_name: result["pool_name"]
      }}
    end
  end
end
