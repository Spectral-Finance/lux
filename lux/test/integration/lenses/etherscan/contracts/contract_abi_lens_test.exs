defmodule Lux.Integration.Etherscan.ContractAbiLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.ContractAbi
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

  defmodule NoAuthContractAbiLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Contract ABI API",
      description: "Fetches the ABI of a verified smart contract",
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
      |> Map.put(:action, "getabi")
      # Ensure chainid is passed through
      |> Map.put_new(:chainid, Map.get(params, :chainid, 1))
    end
  end

  test "can fetch ABI for a verified contract" do
    assert {:ok, %{result: abi}} =
             RateLimitedAPI.call_standard(ContractAbi, :focus, [%{
               address: @contract_address,
               chainid: 1
             }])

    # Verify the ABI structure
    assert is_list(abi)

    # Check that the ABI contains function definitions
    assert Enum.any?(abi, fn item ->
      is_map(item) && Map.has_key?(item, "type")
    end)

    # Log some information about the ABI for informational purposes
    function_count = Enum.count(abi, fn item ->
      is_map(item) && Map.get(item, "type") == "function"
    end)
    event_count = Enum.count(abi, fn item ->
      is_map(item) && Map.get(item, "type") == "event"
    end)

    IO.puts("Contract ABI contains #{length(abi)} items")
    IO.puts("Functions: #{function_count}")
    IO.puts("Events: #{event_count}")
  end

  test "can fetch ABI for another verified contract" do
    assert {:ok, %{result: abi}} =
             RateLimitedAPI.call_standard(ContractAbi, :focus, [%{
               address: @uniswap_router,
               chainid: 1
             }])

    # Verify the ABI structure
    assert is_list(abi)

    # Check that the ABI contains function definitions
    assert Enum.any?(abi, fn item ->
      is_map(item) && Map.has_key?(item, "type")
    end)

    # Log some information about the ABI for informational purposes
    function_count = Enum.count(abi, fn item ->
      is_map(item) && Map.get(item, "type") == "function"
    end)

    IO.puts("Uniswap Router ABI contains #{length(abi)} items")
    IO.puts("Functions: #{function_count}")
  end

  test "returns error for non-verified contract" do
    # Using a random EOA address which won't have verified contract code
    random_address = "0x000000000000000000000000000000000000dEaD"

    result = RateLimitedAPI.call_standard(ContractAbi, :focus, [%{
      address: random_address,
      chainid: 1
    }])

    case result do
      {:ok, %{result: "Contract source code not verified"}} ->
        # This is the expected response for non-verified contracts
        assert true

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthContractAbiLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthContractAbiLens, :focus, [%{
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
