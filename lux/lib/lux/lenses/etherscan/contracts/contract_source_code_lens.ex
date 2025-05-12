defmodule Lux.Lenses.Etherscan.ContractSourceCode do
  @moduledoc """
  Lens for fetching the Solidity source code of a verified smart contract from the Etherscan API.

  ## Examples

  ```elixir
  # Get contract source code for a verified contract (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.ContractSourceCode.focus(%{
    address: "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413"
  })

  # Get contract source code for a verified contract on a specific chain
  Lux.Lenses.Etherscan.ContractSourceCode.focus(%{
    address: "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.ContractSourceCode",
    description: "Retrieves complete source code and metadata for a verified smart contract",
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
          description: "Target contract address with verified source code on Etherscan",
          pattern: "^0x[a-fA-F0-9]{40}$"
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
    |> Map.put(:module, "contract")
    |> Map.put(:action, "getsourcecode")
  end

  @doc """
  Transforms the API response into a more usable format.
  For contract source code, we need to extract the relevant information from the result array.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) and length(result) > 0 ->
        # Extract the first item from the result array
        contract_info = List.first(result)

        # Create a more structured response
        structured_info = %{
          contract_name: contract_info["ContractName"],
          source_code: contract_info["SourceCode"],
          abi: try_parse_abi(contract_info["ABI"]),
          compiler_version: contract_info["CompilerVersion"],
          optimization_used: contract_info["OptimizationUsed"] == "1",
          runs: contract_info["Runs"],
          constructor_arguments: contract_info["ConstructorArguments"],
          library: contract_info["Library"],
          license_type: contract_info["LicenseType"],
          proxy: contract_info["Proxy"] == "1",
          implementation: contract_info["Implementation"],
          swarm_source: contract_info["SwarmSource"]
        }

        {:ok, %{result: structured_info}}

      other ->
        # Pass through other responses (like errors)
        other
    end
  end

  # Helper function to try parsing the ABI JSON string
  defp try_parse_abi(abi) when is_binary(abi) do
    case Jason.decode(abi) do
      {:ok, parsed_abi} -> parsed_abi
      {:error, _} -> abi
    end
  end

  defp try_parse_abi(abi), do: abi
end
