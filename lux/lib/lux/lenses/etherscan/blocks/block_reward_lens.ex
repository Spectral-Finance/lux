defmodule Lux.Lenses.Etherscan.BlockReward do
  @moduledoc """
  Lens for fetching block and uncle rewards for a specific block from the Etherscan API.

  ## Examples

  ```elixir
  # Get block rewards for a specific block (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.BlockReward.focus(%{
    blockno: 2_165_403
  })

  # Get block rewards for a specific block on a specific chain
  Lux.Lenses.Etherscan.BlockReward.focus(%{
    blockno: 2_165_403,
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.BlockReward",
    description: "Retrieves mining rewards for a block including miner compensation and uncle rewards",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        chainid: %{
          type: :integer,
          description: "Network identifier (1=Ethereum, 137=Polygon, 56=BSC, etc.)",
          default: 1
        },
        blockno: %{
          type: [:integer, :string],
          description: "Block height to query reward information for"
        }
      },
      required: ["blockno"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Convert blockno to string if it's an integer
    params = case params[:blockno] do
      blockno when is_integer(blockno) -> Map.put(params, :blockno, to_string(blockno))
      _ -> params
    end

    # Set module and action for this endpoint
    params
    |> Map.put(:module, "block")
    |> Map.put(:action, "getblockreward")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_map(result) ->
        # Extract the relevant information
        block_number = Map.get(result, "blockNumber")
        timestamp = Map.get(result, "timeStamp")
        block_miner = Map.get(result, "blockMiner")
        block_reward = Map.get(result, "blockReward")
        uncles = Map.get(result, "uncles", [])

        # Process uncles to a more structured format
        processed_uncles = Enum.map(uncles, fn uncle ->
          %{
            miner: Map.get(uncle, "miner"),
            uncle_position: Map.get(uncle, "unclePosition"),
            block_reward: Map.get(uncle, "blockreward")
          }
        end)

        # Return a structured response
        {:ok, %{
          result: %{
            block_number: block_number,
            timestamp: timestamp,
            block_miner: block_miner,
            block_reward: block_reward,
            uncles: processed_uncles
          }
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
