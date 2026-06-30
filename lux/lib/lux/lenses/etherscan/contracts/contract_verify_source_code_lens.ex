defmodule Lux.Lenses.Etherscan.ContractVerifySourceCode do
  @moduledoc """
  Lens for submitting a contract source code to Etherscan for verification.

  This endpoint is limited to 100 verifications/day, regardless of API PRO tier.
  The request must be sent using HTTP POST.

  ## Examples

  ```elixir
  # Verify a contract with single file source code
  Lux.Lenses.Etherscan.ContractVerifySourceCode.focus(%{
    chainid: 1,
    contractaddress: "0x123456789012345678901234567890123456789",
    sourceCode: "pragma solidity ^0.8.0; contract MyContract { ... }",
    codeformat: "solidity-single-file",
    contractname: "MyContract",
    compilerversion: "v0.8.0+commit.c7dfd78e",
    optimizationUsed: 1,
    runs: 200
  })

  # Verify a contract with standard JSON input
  Lux.Lenses.Etherscan.ContractVerifySourceCode.focus(%{
    chainid: 1,
    contractaddress: "0x123456789012345678901234567890123456789",
    sourceCode: "{\\"language\\":\\"Solidity\\",\\"sources\\":{\\"contracts/MyContract.sol\\":{\\"content\\":\\"pragma solidity ^0.8.0; contract MyContract { ... }\\"}},\\"settings\\":{\\"optimizer\\":{\\"enabled\\":true,\\"runs\\":200}}}",
    codeformat: "solidity-standard-json-input",
    contractname: "contracts/MyContract.sol:MyContract",
    compilerversion: "v0.8.0+commit.c7dfd78e"
  })

  # Verify a contract with constructor arguments
  Lux.Lenses.Etherscan.ContractVerifySourceCode.focus(%{
    chainid: 1,
    contractaddress: "0x123456789012345678901234567890123456789",
    sourceCode: "pragma solidity ^0.8.0; contract MyContract { constructor(string memory name) { ... } }",
    codeformat: "solidity-single-file",
    contractname: "MyContract",
    compilerversion: "v0.8.0+commit.c7dfd78e",
    optimizationUsed: 1,
    runs: 200,
    constructorArguements: "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000084d79546f6b656e0000000000000000000000000000000000000000000000000000"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.ContractVerifySourceCode",
    description: "Submits contract source code for verification to make it publicly accessible and verified on Etherscan",
    url: "https://api.etherscan.io/v2/api",
    method: :post,
    headers: [{"content-type", "application/x-www-form-urlencoded"}],
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
        contractaddress: %{
          type: :string,
          description: "Deployed contract address to verify source code for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        sourceCode: %{
          type: :string,
          description: "Complete contract source code or JSON input containing source files"
        },
        codeformat: %{
          type: :string,
          description: "Source format (single-file=direct code, standard-json-input=multiple files)",
          enum: ["solidity-single-file", "solidity-standard-json-input"]
        },
        contractname: %{
          type: :string,
          description: "Contract name or path:name for multi-file projects"
        },
        compilerversion: %{
          type: :string,
          description: "Solidity compiler version with commit hash (e.g., 'v0.8.0+commit.c7dfd78e')"
        },
        optimizationUsed: %{
          type: [:integer, :string],
          description: "Compiler optimization flag (1=enabled, 0=disabled)",
          enum: [0, 1, "0", "1"]
        },
        runs: %{
          type: [:integer, :string],
          description: "Optimization runs parameter when optimization is enabled"
        },
        constructorArguements: %{
          type: :string,
          description: "ABI-encoded constructor arguments in hex format (without 0x prefix)"
        },
        evmversion: %{
          type: :string,
          description: "EVM version target for bytecode generation"
        },
        licenseType: %{
          type: [:integer, :string],
          description: "Open source license identifier number"
        },
        libraryname1: %{
          type: :string,
          description: "Name of external library dependency #1"
        },
        libraryaddress1: %{
          type: :string,
          description: "Deployed address of external library dependency #1"
        },
        libraryname2: %{
          type: :string,
          description: "Name of external library dependency #2"
        },
        libraryaddress2: %{
          type: :string,
          description: "Deployed address of external library dependency #2"
        }
      },
      required: ["contractaddress", "sourceCode", "codeformat", "contractname", "compilerversion"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params = params
    |> Map.put(:module, "contract")
    |> Map.put(:action, "verifysourcecode")

    # Convert optimization parameters to strings if they are integers
    params = case params[:optimizationUsed] do
      opt when is_integer(opt) -> Map.put(params, :optimizationUsed, to_string(opt))
      _ -> params
    end

    params = case params[:runs] do
      runs when is_integer(runs) -> Map.put(params, :runs, to_string(runs))
      _ -> params
    end

    params = case params[:licenseType] do
      license when is_integer(license) -> Map.put(params, :licenseType, to_string(license))
      _ -> params
    end

    params
  end

  @doc """
  Transforms the API response into a more usable format.
  For contract verification, we need to extract the GUID from the result.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: guid}} when is_binary(guid) ->
        # Return a structured response with the GUID
        {:ok, %{result: %{guid: guid, status: "Pending"}}}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
