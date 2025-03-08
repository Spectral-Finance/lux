defmodule Lux.Integration.Etherscan.ContractCreationLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.ContractCreation
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Contract addresses from the example in the documentation
  @contract_addresses "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F,0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,0xe4462eb568E2DFbb5b0cA2D3DbB1A35C9Aa98aad"
  # Single contract address (Uniswap V2 Router)
  @single_contract "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthContractCreationLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Contract Creator API",
      description: "Fetches a contract's deployer address and transaction hash it was created",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "contract")
      |> Map.put(:action, "getcontractcreation")
      # Ensure chainid is passed through
      |> Map.put_new(:chainid, Map.get(params, :chainid, 1))
    end
  end

  test "can fetch contract creation info for multiple contracts" do
    assert {:ok, %{result: contracts}} =
             RateLimitedAPI.call_standard(ContractCreation, :focus, [%{
               contractaddresses: @contract_addresses,
               chainid: 1
             }])

    # Verify the result structure
    assert is_list(contracts)
    assert length(contracts) > 0

    # Check that each contract has the expected fields
    Enum.each(contracts, fn contract ->
      assert Map.has_key?(contract, :contract_address)
      assert Map.has_key?(contract, :creator_address)
      assert Map.has_key?(contract, :tx_hash)

      # The addresses should be valid Ethereum addresses
      assert String.starts_with?(contract.contract_address, "0x")
      assert String.length(contract.contract_address) == 42
      assert String.starts_with?(contract.creator_address, "0x")
      assert String.length(contract.creator_address) == 42

      # The transaction hash should be a valid Ethereum transaction hash
      assert String.starts_with?(contract.tx_hash, "0x")
      assert String.length(contract.tx_hash) == 66
    end)

    # Log the contract creation information for informational purposes
    Enum.each(contracts, fn contract ->
      IO.puts("Contract: #{contract.contract_address}")
      IO.puts("Creator: #{contract.creator_address}")
      IO.puts("Creation TX: #{contract.tx_hash}")
      IO.puts("---")
    end)
  end

  test "can fetch contract creation info for a single contract" do
    assert {:ok, %{result: contracts}} =
             RateLimitedAPI.call_standard(ContractCreation, :focus, [%{
               contractaddresses: @single_contract,
               chainid: 1
             }])

    # Verify the result structure
    assert is_list(contracts)
    assert length(contracts) == 1

    # Get the single contract info
    contract = List.first(contracts)

    # Check that the contract has the expected fields
    assert Map.has_key?(contract, :contract_address)
    assert Map.has_key?(contract, :creator_address)
    assert Map.has_key?(contract, :tx_hash)

    # The contract address should match what we requested
    assert String.downcase(contract.contract_address) == String.downcase(@single_contract)

    # Log the contract creation information for informational purposes
    IO.puts("Contract: #{contract.contract_address}")
    IO.puts("Creator: #{contract.creator_address}")
    IO.puts("Creation TX: #{contract.tx_hash}")
  end

  test "returns error for invalid contract address" do
    # Using an invalid address format
    invalid_address = "0xinvalid"

    result = RateLimitedAPI.call_standard(ContractCreation, :focus, [%{
      contractaddresses: invalid_address,
      chainid: 1
    }])

    case result do
      {:error, error} ->
        # Should return an error for invalid address format
        assert error != nil

      {:ok, %{result: []}} ->
        # Or it might return an empty list
        assert true

      {:ok, %{result: error}} when is_binary(error) ->
        # Or it might return an error message
        assert error != nil
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthContractCreationLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthContractCreationLens, :focus, [%{
      contractaddresses: @single_contract,
      chainid: 1
    }])

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        assert String.contains?(error_message, "Missing/Invalid API Key")

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil
    end
  end
end
