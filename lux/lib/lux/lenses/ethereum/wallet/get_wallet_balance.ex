defmodule Lux.Lenses.Ethereum.Wallet.GetWalletBalance do
  @moduledoc """
  A lens for retrieving ETH and ERC-20 token balances for an Ethereum address.

  Queries the balance of an address on any supported EVM chain.
  Optionally fetches ERC-20 token balances using standard contract calls.

  ## Examples

      iex> GetWalletBalance.focus(%{
      ...>   address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
      ...>   network: "mainnet"
      ...> }, %{agent: %{name: "TestAgent"}})
      {:ok, %{
        address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        eth_balance: "1.5",
        eth_balance_wei: "1500000000000000000",
        network: "mainnet",
        token_balances: []
      }}
  """

  use Lux.Lens,
    name: "Get Wallet Balance",
    description: "Retrieves ETH and ERC-20 token balances for an Ethereum address",
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to query"
        },
        network: %{
          type: :string,
          description: "EVM network to query",
          enum: ["mainnet", "sepolia", "base", "polygon", "arbitrum", "optimism", "test"],
          default: "mainnet"
        },
        token_addresses: %{
          type: :array,
          description: "Optional list of ERC-20 token contract addresses to check",
          items: %{type: :string}
        },
        rpc_url: %{
          type: :string,
          description: "Custom RPC URL (overrides network preset)"
        }
      },
      required: ["address"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  alias Lux.Config

  @networks %{
    "mainnet" => "https://eth-mainnet.g.alchemy.com/v2/",
    "sepolia" => "https://eth-sepolia.g.alchemy.com/v2/",
    "base" => "https://base-mainnet.g.alchemy.com/v2/",
    "polygon" => "https://polygon-mainnet.g.alchemy.com/v2/",
    "arbitrum" => "https://arb-mainnet.g.alchemy.com/v2/",
    "optimism" => "https://opt-mainnet.g.alchemy.com/v2/"
  }

  @impl true
  def focus(input, _agent) do
    address = Map.get(input, :address, "")
    network = Map.get(input, :network, "mainnet")
    token_addresses = Map.get(input, :token_addresses, [])

    with {:ok, rpc_url} <- resolve_rpc(input, network),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- fetch_balance(address, rpc_url, network, token_addresses) do
      {:ok, result}
    else
      {:ok, %{"success" => false, "error" => err}} ->
        {:error, "Failed to import web3: #{err}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_rpc(%{rpc_url: url}, _) when is_binary(url) and url != "", do: {:ok, url}
  defp resolve_rpc(_, "test"), do: {:ok, "test"}
  defp resolve_rpc(_, network) do
    api_key = Config.alchemy_api_key()
    case Map.fetch(@networks, network) do
      {:ok, base} -> {:ok, base <> api_key}
      :error -> {:error, "Unknown network: #{network}"}
    end
  end

  defp fetch_balance(address, rpc_url, network, token_addresses) do
    result =
      python variables: %{
        address: address,
        rpc_url: rpc_url,
        network: network,
        token_addresses: token_addresses
      } do
        ~PY"""
        from web3 import Web3

        # ERC-20 balanceOf ABI (minimal)
        ERC20_ABI = [
            {
                "constant": True,
                "inputs": [{"name": "_owner", "type": "address"}],
                "name": "balanceOf",
                "outputs": [{"name": "balance", "type": "uint256"}],
                "type": "function",
            },
            {
                "constant": True,
                "inputs": [],
                "name": "decimals",
                "outputs": [{"name": "", "type": "uint8"}],
                "type": "function",
            },
            {
                "constant": True,
                "inputs": [],
                "name": "symbol",
                "outputs": [{"name": "", "type": "string"}],
                "type": "function",
            },
        ]

        try:
            if network == "test" or rpc_url == "test":
                w3 = Web3(Web3.EthereumTesterProvider())
            else:
                w3 = Web3(Web3.HTTPProvider(rpc_url))

            if not w3.is_connected():
                raise Exception("Cannot connect to node")

            checksum_addr = w3.to_checksum_address(address)

            # ETH balance
            balance_wei = w3.eth.get_balance(checksum_addr)
            balance_eth = float(Web3.from_wei(balance_wei, "ether"))

            # Token balances
            token_balances = []
            for token_addr in token_addresses:
                try:
                    contract = w3.eth.contract(
                        address=w3.to_checksum_address(token_addr),
                        abi=ERC20_ABI
                    )
                    raw_balance = contract.functions.balanceOf(checksum_addr).call()
                    decimals = contract.functions.decimals().call()
                    symbol = contract.functions.symbol().call()
                    human_balance = raw_balance / (10 ** decimals)
                    token_balances.append({
                        "token_address": token_addr,
                        "symbol": symbol,
                        "balance": str(human_balance),
                        "balance_raw": str(raw_balance),
                        "decimals": decimals
                    })
                except Exception as te:
                    token_balances.append({
                        "token_address": token_addr,
                        "error": str(te)
                    })

            {
                "address": checksum_addr,
                "eth_balance": str(balance_eth),
                "eth_balance_wei": str(balance_wei),
                "network": network,
                "token_balances": token_balances
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, %{
        address: result["address"],
        eth_balance: result["eth_balance"],
        eth_balance_wei: result["eth_balance_wei"],
        network: result["network"],
        token_balances: result["token_balances"]
      }}
    end
  end
end
