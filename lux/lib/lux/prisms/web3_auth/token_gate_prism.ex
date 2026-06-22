defmodule Lux.Prisms.Web3Auth.TokenGatePrism do
  @moduledoc """
  A prism that checks if a Web3 address holds a minimum amount of a specific ERC20 token.
  """

  use Lux.Prism,
    name: "Token Gate Checker",
    description: "Verifies if an Ethereum address holds a required amount of a specific ERC20 token",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to check"
        },
        token_address: %{
          type: :string,
          description: "ERC20 Token contract address"
        },
        min_balance: %{
          type: :number,
          description: "Minimum required balance (in human-readable tokens, e.g. 1.5)"
        },
        network: %{
          type: :string,
          enum: ["mainnet", "goerli", "sepolia", "test"],
          description: "Ethereum network to use",
          default: "mainnet"
        }
      },
      required: ["address", "token_address", "min_balance"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        allowed: %{
          type: :boolean,
          description: "Whether the user holds the minimum balance"
        },
        balance: %{
          type: :number,
          description: "The actual token balance"
        },
        error: %{
          type: :string,
          description: "Error message if check failed"
        }
      },
      required: ["allowed"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(%{address: address, token_address: token_address, min_balance: min_balance} = input, _ctx) do
    network = Map.get(input, :network, "mainnet")

    with {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- check_token_balance(address, token_address, min_balance, network) do
      {:ok, atomize_keys(result)}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import Web3: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_token_balance(address, token_address, min_balance, network) do
    api_key = Config.alchemy_api_key()

    result =
      python variables: %{
               address: address,
               token_address: token_address,
               min_balance: min_balance,
               network: network,
               api_key: api_key
             } do
        ~PY"""
        def check_balance(address, token_address, min_balance, network, api_key):
            from web3 import Web3
            
            try:
                if network == "test":
                    w3 = Web3(Web3.EthereumTesterProvider())
                else:
                    NETWORKS = {
                        "mainnet": f"https://eth-mainnet.g.alchemy.com/v2/{api_key}",
                        "goerli": f"https://eth-goerli.g.alchemy.com/v2/{api_key}",
                        "sepolia": f"https://eth-sepolia.g.alchemy.com/v2/{api_key}"
                    }
                    if network not in NETWORKS:
                        return {"allowed": False, "error": f"Invalid network: {network}"}
                    w3 = Web3(Web3.HTTPProvider(NETWORKS[network]))
                
                checksum_addr = w3.to_checksum_address(address)
                token_checksum = w3.to_checksum_address(token_address)
                
                # Minimal ERC20 ABI for balanceOf and decimals
                erc20_abi = [
                    {
                        "constant": True,
                        "inputs": [{"name": "_owner", "type": "address"}],
                        "name": "balanceOf",
                        "outputs": [{"name": "balance", "type": "uint256"}],
                        "type": "function"
                    },
                    {
                        "constant": True,
                        "inputs": [],
                        "name": "decimals",
                        "outputs": [{"name": "", "type": "uint8"}],
                        "type": "function"
                    }
                ]
                
                contract = w3.eth.contract(address=token_checksum, abi=erc20_abi)
                
                decimals = contract.functions.decimals().call()
                raw_balance = contract.functions.balanceOf(checksum_addr).call()
                
                actual_balance = raw_balance / (10 ** decimals)
                
                return {
                    "allowed": actual_balance >= min_balance,
                    "balance": float(actual_balance)
                }
            except Exception as e:
                return {
                    "allowed": False,
                    "error": f"Failed to check token balance: {str(e)}"
                }

        result = check_balance(address, token_address, min_balance, network, api_key)
        result
        """
      end

    {:ok, result}
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
