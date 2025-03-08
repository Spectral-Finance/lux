defmodule Lux.Lenses.Etherscan.MinedBlocks do
  @moduledoc """
  Lens for fetching blocks validated (mined) by an Ethereum address from the Etherscan API.

  ## Examples

  ```elixir
  # Get blocks validated by an address (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.MinedBlocks.focus(%{
    address: "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b"
  })

  # Get blocks validated by an address with pagination
  Lux.Lenses.Etherscan.MinedBlocks.focus(%{
    address: "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b",
    blocktype: "blocks",
    page: 1,
    offset: 10
  })

  # Get uncle blocks validated by an address
  Lux.Lenses.Etherscan.MinedBlocks.focus(%{
    address: "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b",
    blocktype: "uncles"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.MinedBlocks",
    description: "Retrieves blocks or uncles validated by a miner/validator address with pagination support",
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
        address: %{
          type: :string,
          description: "Miner/validator address that produced the blocks",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        blocktype: %{
          type: :string,
          description: "Block category to return (blocks=main chain, uncles=orphaned blocks)",
          enum: ["blocks", "uncles"],
          default: "blocks"
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results (starts at 1)",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of block records to return per page",
          default: 10
        }
      },
      required: ["address"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "account")
    |> Map.put(:action, "getminedblocks")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    Base.process_response(response)
  end
end
