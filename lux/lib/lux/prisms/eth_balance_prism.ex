defmodule Lux.Prisms.EthBalancePrism do
  @moduledoc """
  A simple prism that checks an Ethereum account's balance.

  ## Examples

      iex> Lux.Prisms.EthBalancePrism.run(%{
      ...>   address: "0xd3cda913deb6f67967b99d67acdfa1712c293601",
      ...>   network: "mainnet"
      ...> })
      {:ok, %{
        balance_eth: 1.5,
        balance_wei: "1500000000000000000",
        network: "mainnet"
      }}
  """

  use Lux.Prism,
    name: "ETH Balance Checker",
    description: "Checks an Ethereum account's balance",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to check"
        },
        network: %{
          type: :string,
          enum: ["mainnet", "goerli", "sepolia", "test"],
          description: "Ethereum network to use",
          default: "mainnet"
        }
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        balance_eth: %{
          type: :number,
          description: "Balance in ETH"
        },
        balance_wei: %{
          type: :string,
          description: "Balance in Wei (as string to handle large numbers)"
        },
        network: %{
          type: :string,
          description: "Network used for query"
        }
      },
      required: ["balance_eth", "balance_wei", "network"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(%{address: address} = input, _ctx) do
    network = Map.get(input, :network, "mainnet")

    with {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- check_balance(address, network) do
      {:ok, atomize_keys(result)}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import Web3: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_balance(address, network) do
    api_key = Config.alchemy_api_key()

    result =
      python variables: %{address: address, network: network, api_key: api_key} do
        ~PY"""
        def get_balance(address, network, api_key):
            from web3 import Web3

            try:
                # Use test provider for tests, real endpoints for production
                if network == "test":
                    w3 = Web3(Web3.EthereumTesterProvider())
                else:
                    # Network endpoints with API key
                    NETWORKS = {
                        "mainnet": f"https://eth-mainnet.g.alchemy.com/v2/{api_key}",
                        "goerli": f"https://eth-goerli.g.alchemy.com/v2/{api_key}",
                        "sepolia": f"https://eth-sepolia.g.alchemy.com/v2/{api_key}"
                    }
                    if network not in NETWORKS:
                        return {
                            "error": f"Invalid network: {network}"
                        }
                    w3 = Web3(Web3.HTTPProvider(NETWORKS[network]))

                # Convert address to checksum address
                checksum_address = w3.to_checksum_address(address)

                # Get balance in Wei
                balance_wei = w3.eth.get_balance(checksum_address)

                # Convert to ETH
                balance_eth = Web3.from_wei(balance_wei, 'ether')

                return {
                    "balance_eth": float(balance_eth),
                    "balance_wei": str(balance_wei),
                    "network": network
                }
            except Exception as e:
                return {
                    "error": f"Failed to get balance: {str(e)}"
                }

        # Call the function with our variables
        result = get_balance(address, network, api_key)
        result  # Return the result
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, result}
    end
  end

  # Convert string keys to atoms in maps
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
