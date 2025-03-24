defmodule Lux.Integration.Etherscan.ContractCreationLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.ContractCreation
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Contract addresses from the example in the documentation
  @contract_addresses "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F,0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,0xe4462eb568E2DFbb5b0cA2D3DbB1A35C9Aa98aad"
  # Single contract address (Uniswap V2 Router)
  @single_contract "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch contract creation info for multiple contracts" do
    assert {:ok, %{result: contracts}} =
             ContractCreation.focus(%{
               contractaddresses: @contract_addresses,
               chainid: 1
             })

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
  end

  test "can fetch contract creation info for a single contract" do
    assert {:ok, %{result: contracts}} =
             ContractCreation.focus(%{
               contractaddresses: @single_contract,
               chainid: 1
             })

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
  end
end
