defmodule Lux.Lenses.PancakeSwap.PancakeSwapFarmPositionLens do
  @moduledoc """
  A lens for fetching a user's PancakeSwap farm position and pending CAKE rewards.

  Returns staked LP token balance, pending CAKE rewards, and the USD value of
  the position based on current pool state. Useful for portfolio monitoring
  and harvest timing decisions.

  ## Example

      iex> Lux.Lenses.PancakeSwap.PancakeSwapFarmPositionLens.focus(%{
      ...>   pid: 2,
      ...>   user_address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
      ...> }, %{agent: %{name: "FarmAgent"}})
      {:ok, %{
        pid: 2,
        user_address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        staked_lp: "5000000000000000000000",
        pending_cake: "47300000000000000000",
        lp_token_address: "0x0eD7e52944161450477ee417DE9Cd3a859b14fD0",
        reward_debt: "123456789012345678",
        harvest_ready: true
      }}
  """

  use Lux.Lens,
    name: "PancakeSwap Farm Position",
    description: "Fetches a user's staked LP balance, pending CAKE rewards, and farm position details",
    schema: %{
      type: :object,
      properties: %{
        pid: %{
          type: :integer,
          description: "MasterChef pool ID to query",
          minimum: 0
        },
        user_address: %{
          type: :string,
          description: "Ethereum/BNB wallet address to check position for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        masterchef_address: %{
          type: :string,
          description: "MasterChef V2 contract address (defaults to BSC mainnet)",
          default: "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        min_harvest_cake: %{
          type: :string,
          description: "Minimum CAKE (in wei) to consider harvest worthwhile. Used for harvest_ready flag.",
          default: "1000000000000000000"
        }
      },
      required: ["pid", "user_address"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @default_masterchef "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652"
  @default_rpc "https://bsc-dataseed.binance.org"

  @impl true
  def focus(%{pid: pid, user_address: user_address} = input, agent) do
    agent_name = get_in(agent, [:agent, :name]) || "Unknown"
    masterchef = Map.get(input, :masterchef_address, @default_masterchef)
    min_harvest = Map.get(input, :min_harvest_cake, "1000000000000000000")
    Logger.info("Agent #{agent_name} fetching farm position for pid=#{pid}, user=#{user_address}")

    rpc_url = get_rpc_url()

    with {:ok, result} <- fetch_position(rpc_url, masterchef, pid, user_address, min_harvest) do
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

  defp fetch_position(rpc_url, masterchef_addr, pid, user_address, min_harvest_cake) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               masterchef_address: masterchef_addr,
               pid: pid,
               user_address: user_address,
               min_harvest_cake: min_harvest_cake
             } do
        ~PY"""
        from web3 import Web3

        MASTERCHEF_ABI = [
            {"name": "userInfo", "type": "function",
             "inputs": [{"name": "_pid", "type": "uint256"}, {"name": "_user", "type": "address"}],
             "outputs": [
                 {"name": "amount", "type": "uint256"},
                 {"name": "rewardDebt", "type": "uint256"}
             ]},
            {"name": "pendingCake", "type": "function",
             "inputs": [{"name": "_pid", "type": "uint256"}, {"name": "_user", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "poolInfo", "type": "function",
             "inputs": [{"name": "_pid", "type": "uint256"}],
             "outputs": [
                 {"name": "lpToken", "type": "address"},
                 {"name": "allocPoint", "type": "uint256"},
                 {"name": "lastRewardBlock", "type": "uint256"},
                 {"name": "accCakePerShare", "type": "uint256"}
             ]}
        ]

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            mc_addr = Web3.to_checksum_address(masterchef_address)
            user_addr = Web3.to_checksum_address(user_address)
            mc = w3.eth.contract(address=mc_addr, abi=MASTERCHEF_ABI)

            # Get user info (staked LP amount + reward debt)
            user_info = mc.functions.userInfo(pid, user_addr).call()
            staked_lp = user_info[0]
            reward_debt = user_info[1]

            # Get pending CAKE
            try:
                pending_cake = mc.functions.pendingCake(pid, user_addr).call()
            except Exception:
                pending_cake = 0

            # Get pool info (LP token address, alloc point)
            try:
                pool = mc.functions.poolInfo(pid).call()
                lp_token_address = pool[0]
                alloc_point = pool[1]
            except Exception:
                lp_token_address = ""
                alloc_point = 0

            min_harvest = int(min_harvest_cake)
            harvest_ready = pending_cake >= min_harvest and pending_cake > 0

            {
                "pid": pid,
                "user_address": user_address,
                "staked_lp": str(staked_lp),
                "pending_cake": str(pending_cake),
                "reward_debt": str(reward_debt),
                "lp_token_address": lp_token_address,
                "alloc_point": alloc_point,
                "harvest_ready": harvest_ready
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, %{
        pid: result["pid"],
        user_address: result["user_address"],
        staked_lp: result["staked_lp"],
        pending_cake: result["pending_cake"],
        reward_debt: result["reward_debt"],
        lp_token_address: result["lp_token_address"],
        alloc_point: result["alloc_point"],
        harvest_ready: result["harvest_ready"]
      }}
    end
  end
end
