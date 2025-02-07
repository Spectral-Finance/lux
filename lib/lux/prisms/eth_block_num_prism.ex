defmodule Lux.Prisms.EthBlockNumPrism do
  @moduledoc """
  A simple prism that checks the current Ethereum block number.

  ## Examples

      iex> Lux.Prisms.EthBlockNumPrism.run(%{
      ...>   network: "mainnet"
      ...> })
      {:ok, %{
        block_number: 123456,
        network: "mainnet"
      }}
  """

  use Lux.Prism,
    name: "ETH Latest Block Number",
    description: "Checks the current Ethereum block number",
    input_schema: %{
      type: :object,
      properties: %{
        network: %{
          type: :string,
          enum: ["mainnet", "goerli", "sepolia"],
          description: "Ethereum network to use",
          default: "mainnet"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        block_number: %{
          type: :integer,
          description: "Current block number"
        },
        network: %{
          type: :string,
          description: "Network used for query"
        }
      },
      required: ["block_number", "network"]
    }

  import Lux.NodeJS

  alias Lux.Config

  require Lux.NodeJS

  def handler(input, _context) do
    network = Map.get(input, :network, "mainnet")

    with {:ok, _} <- import_package("web3"),
         {:ok, result} <- get_latest_block_number(network) do
      {:ok, %{block_number: result, network: network}}
    end
  end

  defp get_latest_block_number(network) do
    api_key = Config.alchemy_api_key()

    nodejs variables: %{network: network, api_key: api_key} do
      ~JS"""
        import {Web3} from 'web3';

        export const main = async ({network, api_key}) => {
          const NETWORKS = {
            mainnet: `https://eth-mainnet.alchemyapi.io/v2/${api_key}`,
            goerli: `https://eth-goerli.alchemyapi.io/v2/${api_key}`,
            sepolia: `https://eth-sepolia.alchemyapi.io/v2/${api_key}`
          };

          const selectedNetwork = NETWORKS[network];

          if (!selectedNetwork) {
            throw new Error('Invalid network');
          }

          const web3 = new Web3(selectedNetwork);

          const blockNumber = await web3.eth.getBlockNumber();
          return BigInt(blockNumber).toString();
        };
      """
    end
  end
end
