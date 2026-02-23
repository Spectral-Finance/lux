defmodule Lux.Lenses.Curve.CurvePositionLens do
  @moduledoc """
  A lens for fetching a user's Curve Finance LP position and pending rewards.

  Returns LP token balance, underlying token amounts, current USD value,
  and pending CRV rewards from any staked gauge.

  ## Example

      iex> Lux.Lenses.Curve.CurvePositionLens.focus(%{
      ...>   pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
      ...>   lp_token_address: "0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490",
      ...>   gauge_address: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A",
      ...>   user_address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
      ...> }, %{agent: %{name: "PortfolioAgent"}})
      {:ok, %{
        user_address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
        lp_balance: "500000000000000000000",
        staked_balance: "300000000000000000000",
        total_lp: "800000000000000000000",
        underlying_amounts: ["265000000000000000000", "267000000", "266000000"],
        position_usd: 798.5,
        pending_crv: "12500000000000000000",
        share_of_pool: 0.00003
      }}
  """

  use Lux.Lens,
    name: "Curve Position",
    description: "Fetches user's LP position, staked balance, underlying tokens, and pending CRV rewards",
    schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Curve pool contract address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        lp_token_address: %{
          type: :string,
          description: "LP token contract address (often same as pool for older pools)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        gauge_address: %{
          type: :string,
          description: "Curve gauge address for staked LP balance and pending CRV (optional)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        user_address: %{
          type: :string,
          description: "Ethereum wallet address to check position for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["pool_address", "lp_token_address", "user_address"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @impl true
  def focus(%{pool_address: pool_address, lp_token_address: lp_token, user_address: user_address} = input, agent) do
    agent_name = get_in(agent, [:agent, :name]) || "Unknown"
    gauge_address = Map.get(input, :gauge_address, nil)
    Logger.info("Agent #{agent_name} fetching Curve position for #{user_address} in #{pool_address}")

    rpc_url = get_rpc_url()

    with {:ok, result} <- fetch_position(rpc_url, pool_address, lp_token, gauge_address, user_address) do
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

  defp fetch_position(rpc_url, pool_address, lp_token_address, gauge_address, user_address) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               pool_address: pool_address,
               lp_token_address: lp_token_address,
               gauge_address: gauge_address,
               user_address: user_address
             } do
        ~PY"""
        from web3 import Web3

        ERC20_ABI = [
            {"name": "balanceOf", "type": "function",
             "inputs": [{"name": "account", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "totalSupply", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        GAUGE_ABI = [
            {"name": "balanceOf", "type": "function",
             "inputs": [{"name": "arg0", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "claimable_tokens", "type": "function",
             "inputs": [{"name": "addr", "type": "address"}],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        POOL_ABI = [
            {"name": "get_virtual_price", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "calc_withdraw_one_coin", "type": "function",
             "inputs": [{"name": "_token_amount", "type": "uint256"}, {"name": "i", "type": "int128"}],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "balances", "type": "function",
             "inputs": [{"name": "i", "type": "uint256"}],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            user_addr = Web3.to_checksum_address(user_address)
            pool_addr = Web3.to_checksum_address(pool_address)
            lp_addr = Web3.to_checksum_address(lp_token_address)

            lp_token = w3.eth.contract(address=lp_addr, abi=ERC20_ABI)
            pool = w3.eth.contract(address=pool_addr, abi=POOL_ABI)

            # LP balance (unstaked)
            lp_balance = lp_token.functions.balanceOf(user_addr).call()
            total_supply = lp_token.functions.totalSupply().call()

            # Staked balance + pending CRV from gauge
            staked_balance = 0
            pending_crv = 0
            if gauge_address:
                gauge_addr = Web3.to_checksum_address(gauge_address)
                gauge = w3.eth.contract(address=gauge_addr, abi=GAUGE_ABI)
                staked_balance = gauge.functions.balanceOf(user_addr).call()
                try:
                    pending_crv = gauge.functions.claimable_tokens(user_addr).call()
                except Exception:
                    pending_crv = 0

            total_lp = lp_balance + staked_balance

            # Virtual price to compute USD value (virtual_price is 1e18 = $1)
            virtual_price = pool.functions.get_virtual_price().call()

            # Share of pool
            share = total_lp / total_supply if total_supply > 0 else 0

            # Estimate underlying amounts (proportional to pool balances)
            underlying_amounts = []
            for i in range(4):
                try:
                    pool_bal = pool.functions.balances(i).call()
                    underlying_amounts.append(str(int(pool_bal * share)))
                except Exception:
                    break

            # Position USD value: total_lp * virtual_price / 1e18 / 1e18 * total_supply...
            # Better: position_usd = total_lp * virtual_price / 1e18 / 1e18
            position_usd = round(total_lp * virtual_price / (10**36), 4)

            {
                "user_address": user_address,
                "pool_address": pool_address,
                "lp_balance": str(lp_balance),
                "staked_balance": str(staked_balance),
                "total_lp": str(total_lp),
                "underlying_amounts": underlying_amounts,
                "position_usd": position_usd,
                "pending_crv": str(pending_crv),
                "share_of_pool": round(share, 8),
                "virtual_price": str(virtual_price)
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, %{
        user_address: result["user_address"],
        pool_address: result["pool_address"],
        lp_balance: result["lp_balance"],
        staked_balance: result["staked_balance"],
        total_lp: result["total_lp"],
        underlying_amounts: result["underlying_amounts"],
        position_usd: result["position_usd"],
        pending_crv: result["pending_crv"],
        share_of_pool: result["share_of_pool"],
        virtual_price: result["virtual_price"]
      }}
    end
  end
end
