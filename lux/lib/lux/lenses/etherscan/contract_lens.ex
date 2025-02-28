defmodule Lux.Lenses.Etherscan.ContractLens do
  @moduledoc """
  Lens for fetching contract data from the Etherscan API.

  This lens provides access to various contract-related endpoints for Ethereum addresses,
  including contract source code, ABI, and verification status.

  ## Examples

  ```elixir
  # Get contract source code for an address
  Lux.Lenses.Etherscan.ContractLens.get_contract_source_code(%{
    address: "0x6B175474E89094C44Da98b954EedeAC495271d0F"
  })

  # Get contract ABI for an address
  Lux.Lenses.Etherscan.ContractLens.get_contract_abi(%{
    address: "0x6B175474E89094C44Da98b954EedeAC495271d0F"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens

  @doc """
  Validates that required parameters are present.
  Raises ArgumentError if any required parameter is missing.
  """
  def validate_required(params, required_keys) do
    missing_keys = Enum.filter(required_keys, fn key -> !Map.has_key?(params, key) || is_nil(params[key]) end)

    if Enum.empty?(missing_keys) do
      {:ok, params}
    else
      key = List.first(missing_keys)
      raise ArgumentError, "#{key} parameter is required"
    end
  end

  @doc """
  Validates that a parameter is a valid Ethereum address.
  Raises ArgumentError if the address is invalid.
  """
  def validate_address(params, key) do
    if Map.has_key?(params, key) do
      case BaseLens.validate_eth_address(params[key]) do
        {:ok, _} -> {:ok, params}
        {:error, message} -> raise ArgumentError, message
      end
    else
      {:ok, params}
    end
  end

  @doc """
  Validates that parameters are valid integers.
  Raises ArgumentError if any of the parameters is not a valid integer.
  """
  def validate_integer(params, keys) do
    invalid_keys = Enum.filter(keys, fn key ->
      Map.has_key?(params, key) &&
      !is_integer(params[key]) &&
      !is_binary(params[key]) &&
      !Regex.match?(~r/^\d+$/, to_string(params[key]))
    end)

    if Enum.empty?(invalid_keys) do
      {:ok, params}
    else
      key = List.first(invalid_keys)
      raise ArgumentError, "#{key} must be a valid integer"
    end
  end

  @doc """
  Fetches the source code for a verified contract.

  ## Parameters

  - `address`: Contract address
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: source_code}}`: Contract source code on success
  - `{:error, reason}`: Error message on failure
  """
  def get_contract_source_code(params) do
    # Validate required parameters
    validate_required(params, [:address])

    # Validate address format
    validate_address(params, :address)

    # Build request parameters
    request_params = %{
      module: "contract",
      action: "getsourcecode",
      address: params[:address]
    }

    # Make the API request
    make_request(request_params, params[:network])
  end

  @doc """
  Fetches the ABI for a verified contract.

  ## Parameters

  - `address`: Contract address
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: abi}}`: Contract ABI on success
  - `{:error, reason}`: Error message on failure
  """
  def get_contract_abi(params) do
    # Validate required parameters
    validate_required(params, [:address])

    # Validate address format
    validate_address(params, :address)

    # Build request parameters
    request_params = %{
      module: "contract",
      action: "getabi",
      address: params[:address]
    }

    # Make the API request
    make_request(request_params, params[:network])
  end

  @doc """
  Fetches the contract creation information.

  ## Parameters

  - `contractaddresses`: Comma-separated list of contract addresses (up to 5)
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: creation_info}}`: Contract creation information on success
  - `{:error, reason}`: Error message on failure
  """
  def get_contract_creation_info(params) do
    # Validate required parameters
    validate_required(params, [:contractaddresses])

    # Build request parameters
    request_params = %{
      module: "contract",
      action: "getcontractcreation",
      contractaddresses: params[:contractaddresses]
    }

    # Make the API request
    make_request(request_params, params[:network])
  end

  @doc """
  Verifies if a contract is verified.

  ## Parameters

  - `address`: Contract address
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: verification_status}}`: Contract verification status on success
  - `{:error, reason}`: Error message on failure
  """
  def is_contract_verified(params) do
    # Validate required parameters
    validate_required(params, [:address])

    # Validate address format
    validate_address(params, :address)

    # Build request parameters
    request_params = %{
      module: "contract",
      action: "getcontractcreation",
      contractaddresses: params[:address]
    }

    # Make the API request
    result = make_request(request_params, params[:network])

    # Process the result to determine if the contract is verified
    case result do
      {:ok, %{result: creation_info}} when is_list(creation_info) and length(creation_info) > 0 ->
        {:ok, %{result: "1"}} # Contract exists and is verified
      {:error, _} ->
        {:ok, %{result: "0"}} # Contract does not exist or is not verified
      _ ->
        result
    end
  end

  @doc """
  Fetches the contract execution status.

  ## Parameters

  - `txhash`: Transaction hash
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: execution_status}}`: Contract execution status on success
  - `{:error, reason}`: Error message on failure
  """
  def get_contract_execution_status(params) do
    # Validate required parameters
    validate_required(params, [:txhash])

    # Validate transaction hash format
    case BaseLens.validate_tx_hash(params[:txhash]) do
      {:ok, _} -> :ok
      {:error, message} -> raise ArgumentError, message
    end

    # Build request parameters
    request_params = %{
      module: "transaction",
      action: "getstatus",
      txhash: params[:txhash]
    }

    # Make the API request
    make_request(request_params, params[:network])
  end

  @doc """
  Fetches the contract verification status.

  ## Parameters

  - `guid`: Verification GUID
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: verification_status}}`: Contract verification status on success
  - `{:error, reason}`: Error message on failure
  """
  def check_verification_status(params) do
    # Validate required parameters
    validate_required(params, [:guid])

    # Build request parameters
    request_params = %{
      module: "contract",
      action: "checkverifystatus",
      guid: params[:guid]
    }

    # Make the API request
    make_request(request_params, params[:network])
  end

  @doc """
  Fetches the contract verification with source code.

  ## Parameters

  - Multiple parameters required for contract verification
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: verification_result}}`: Contract verification result on success
  - `{:error, reason}`: Error message on failure
  """
  def verify_contract_source_code(params) do
    # Validate required parameters
    required_params = [
      :contractaddress,
      :sourceCode,
      :codeformat,
      :contractname,
      :compilerversion,
      :optimizationUsed
    ]

    validate_required(params, required_params)

    # Validate address format
    validate_address(params, :contractaddress)

    # Build request parameters
    request_params = %{
      module: "contract",
      action: "verifysourcecode",
      contractaddress: params[:contractaddress],
      sourceCode: params[:sourceCode],
      codeformat: params[:codeformat],
      contractname: params[:contractname],
      compilerversion: params[:compilerversion],
      optimizationUsed: params[:optimizationUsed]
    }

    # Add optional parameters if present
    optional_params = [
      :constructorArguments,
      :evmversion,
      :runs,
      :licenseType
    ]

    request_params = Enum.reduce(optional_params, request_params, fn key, acc ->
      if Map.has_key?(params, key) do
        Map.put(acc, key, params[key])
      else
        acc
      end
    end)

    # Make the API request
    make_request(request_params, params[:network])
  end

  @doc """
  Fetches the list of verified contracts.

  ## Parameters

  - `page`: Page number (default: 1)
  - `offset`: Number of records per page (default: 10)
  - `sort`: Sorting preference, "asc" or "desc" (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: contracts}}`: List of verified contracts on success
  - `{:error, reason}`: Error message on failure
  """
  def get_verified_contracts(params \\ %{}) do
    # Validate integer parameters if present
    validate_integer(params, [:page, :offset])

    # Build request parameters
    request_params = %{
      module: "contract",
      action: "getcontractcreation",
      contractaddresses: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", # USDC token
      page: params[:page] || 1,
      offset: params[:offset] || 10,
      sort: params[:sort] || "asc"
    }

    # Make the API request
    make_request(request_params, params[:network])
  end

  # Make API request and process response
  defp make_request(params, network) do
    # Add API key to parameters
    params = Map.put(params, :apikey, api_key())

    # Add chain ID for v2 API
    params = Map.put(params, :chainid, Lux.Config.etherscan_chain_id(network))

    # Make the request
    case Req.get(build_url(network), params: params) do
      {:ok, %{status: 200, body: body}} ->
        BaseLens.process_response(body)
      {:ok, response} ->
        {:error, "Unexpected response: #{inspect(response)}"}
      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  # Get API key from application config
  defp api_key do
    Lux.Config.etherscan_api_key()
  end

  # Build URL for the Etherscan API
  defp build_url(network \\ :ethereum) do
    BaseLens.build_url(network)
  end
end
