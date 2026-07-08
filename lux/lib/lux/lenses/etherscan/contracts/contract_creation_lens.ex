defmodule Lux.Lenses.Etherscan.ContractCreation do
  @moduledoc """
  Lens for fetching a contract's deployer address and transaction hash it was created from the Etherscan API.

  This endpoint supports up to 5 contract addresses at a time.

  ## Examples

  ```elixir
  # Get contract creator info for a single contract (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.ContractCreation.focus(%{
    contractaddresses: "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F"
  })

  # Get contract creator info for multiple contracts (up to 5)
  Lux.Lenses.Etherscan.ContractCreation.focus(%{
    contractaddresses: "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F,0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,0xe4462eb568E2DFbb5b0cA2D3DbB1A35C9Aa98aad"
  })

  # Get contract creator info for contracts on a specific chain
  Lux.Lenses.Etherscan.ContractCreation.focus(%{
    contractaddresses: "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.ContractCreation",
    description: "Identifies the creator address and deployment transaction for up to 5 contracts",
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
        contractaddresses: %{
          type: :string,
          description: "Comma-separated list of contract addresses to query (maximum 5)",
          pattern: "^(0x[a-fA-F0-9]{40})(,0x[a-fA-F0-9]{40}){0,4}$"
        }
      },
      required: ["contractaddresses"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "contract")
    |> Map.put(:action, "getcontractcreation")
  end

  @doc """
  Transforms the API response into a more usable format.
  For contract creation info, we need to ensure the result is properly structured.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        # Transform the result into a more structured format
        structured_result = Enum.map(result, fn contract ->
          %{
            contract_address: contract["contractAddress"],
            creator_address: contract["contractCreator"],
            tx_hash: contract["txHash"]
          }
        end)

        {:ok, %{result: structured_result}}

      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
