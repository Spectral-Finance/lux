defmodule Lux.Integration.Etherscan.ContractSourceCodeLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.ContractSourceCode
  import Lux.Integration.Etherscan.RateLimitedAPI

  # The DAO contract address (verified contract from the example in the documentation)
  @contract_address "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413"
  # Another verified contract (Uniswap V2 Router)
  @uniswap_router "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch source code for a verified contract" do
    assert {:ok, %{result: source_info}} =
             ContractSourceCode.focus(%{
               address: @contract_address,
               chainid: 1
             })

    # Verify the source code structure
    assert is_map(source_info)

    # Check that the source code info contains the expected fields
    assert Map.has_key?(source_info, :contract_name)
    assert Map.has_key?(source_info, :source_code)
    assert Map.has_key?(source_info, :abi)
    assert Map.has_key?(source_info, :compiler_version)
    assert Map.has_key?(source_info, :optimization_used)
    assert Map.has_key?(source_info, :license_type)

    # The source code should be a non-empty string
    assert is_binary(source_info.source_code)
    assert String.length(source_info.source_code) > 0

    # The contract name should be a non-empty string
    assert is_binary(source_info.contract_name)
    assert String.length(source_info.contract_name) > 0
  end

  test "can fetch source code for another verified contract" do
    assert {:ok, %{result: source_info}} =
             ContractSourceCode.focus(%{
               address: @uniswap_router,
               chainid: 1
             })

    # Verify the source code structure
    assert is_map(source_info)

    # Check that the source code info contains the expected fields
    assert Map.has_key?(source_info, :contract_name)
    assert Map.has_key?(source_info, :source_code)

    # The source code should be a non-empty string
    assert is_binary(source_info.source_code)
    assert String.length(source_info.source_code) > 0
  end

  test "returns empty source for non-verified contract" do
    # Using a random EOA address which won't have verified contract code
    random_address = "0x000000000000000000000000000000000000dEaD"

    assert {:ok, %{result: source_info}} =
             ContractSourceCode.focus(%{
               address: random_address,
               chainid: 1
             })

    # Verify the source code structure
    assert is_map(source_info)

    # For non-verified contracts, the source code should be empty
    assert source_info.source_code == ""

    # The contract name should also be empty
    assert source_info.contract_name == ""
  end
end
