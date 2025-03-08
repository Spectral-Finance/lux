defmodule Lux.Integration.Etherscan.ContractSourceCodeLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.ContractSourceCode
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # The DAO contract address (verified contract from the example in the documentation)
  @contract_address "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413"
  # Another verified contract (Uniswap V2 Router)
  @uniswap_router "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthContractSourceCodeLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Contract Source Code API",
      description: "Fetches the source code of a verified smart contract",
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
      |> Map.put(:action, "getsourcecode")
      # Ensure chainid is passed through
      |> Map.put_new(:chainid, Map.get(params, :chainid, 1))
    end
  end

  test "can fetch source code for a verified contract" do
    assert {:ok, %{result: source_info}} =
             RateLimitedAPI.call_standard(ContractSourceCode, :focus, [%{
               address: @contract_address,
               chainid: 1
             }])

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

    # Log some information about the source code for informational purposes
    IO.puts("Contract name: #{source_info.contract_name}")
    IO.puts("Compiler version: #{source_info.compiler_version}")
    IO.puts("Optimization used: #{source_info.optimization_used}")
    IO.puts("License type: #{source_info.license_type}")

    # Log the first 100 characters of the source code
    source_preview = String.slice(source_info.source_code, 0..100)
    IO.puts("Source code preview: #{source_preview}...")
  end

  test "can fetch source code for another verified contract" do
    assert {:ok, %{result: source_info}} =
             RateLimitedAPI.call_standard(ContractSourceCode, :focus, [%{
               address: @uniswap_router,
               chainid: 1
             }])

    # Verify the source code structure
    assert is_map(source_info)

    # Check that the source code info contains the expected fields
    assert Map.has_key?(source_info, :contract_name)
    assert Map.has_key?(source_info, :source_code)

    # The source code should be a non-empty string
    assert is_binary(source_info.source_code)
    assert String.length(source_info.source_code) > 0

    # Log some information about the source code for informational purposes
    IO.puts("Contract name: #{source_info.contract_name}")
    IO.puts("Compiler version: #{source_info.compiler_version}")
  end

  test "returns empty source for non-verified contract" do
    # Using a random EOA address which won't have verified contract code
    random_address = "0x000000000000000000000000000000000000dEaD"

    assert {:ok, %{result: source_info}} =
             RateLimitedAPI.call_standard(ContractSourceCode, :focus, [%{
               address: random_address,
               chainid: 1
             }])

    # Verify the source code structure
    assert is_map(source_info)

    # For non-verified contracts, the source code should be empty
    assert source_info.source_code == ""

    # The contract name should also be empty
    assert source_info.contract_name == ""
  end

  test "fails when no auth is provided" do
    # The NoAuthContractSourceCodeLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthContractSourceCodeLens, :focus, [%{
      address: @contract_address,
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
