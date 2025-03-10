defmodule Lux.Integration.Etherscan.GasOracleLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.GasOracle
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthGasOracleLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Gas Oracle API",
      description: "Fetches the current Safe, Proposed and Fast gas prices",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "gastracker")
      |> Map.put(:action, "gasoracle")
      # Ensure chainid is passed through
      |> Map.put_new(:chainid, Map.get(params, :chainid, 1))
    end
  end

  test "can fetch current gas prices" do
    # Always include chainid parameter for v2 API
    assert {:ok, %{result: gas_info}} = RateLimitedAPI.call_standard(GasOracle, :focus, [%{chainid: 1}])

    # Verify the gas info structure
    assert is_map(gas_info)

    # Check that the gas info contains the expected fields
    assert Map.has_key?(gas_info, :safe_gas_price)
    assert Map.has_key?(gas_info, :propose_gas_price)
    assert Map.has_key?(gas_info, :fast_gas_price)
    assert Map.has_key?(gas_info, :suggest_base_fee)
    assert Map.has_key?(gas_info, :gas_used_ratio)
    assert Map.has_key?(gas_info, :last_block)

    # The gas prices should be numeric values
    assert is_number(gas_info.safe_gas_price)
    assert is_number(gas_info.propose_gas_price)
    assert is_number(gas_info.fast_gas_price)
    assert is_number(gas_info.suggest_base_fee)

    # The last block should be an integer
    assert is_integer(gas_info.last_block)
  end

  test "can fetch gas prices for a specific chain" do
    # Using Ethereum mainnet (chainid: 1)
    assert {:ok, %{result: gas_info}} = RateLimitedAPI.call_standard(GasOracle, :focus, [%{chainid: 1}])

    # Verify the gas info structure
    assert is_map(gas_info)

    # Check that the gas info contains the expected fields
    assert Map.has_key?(gas_info, :safe_gas_price)
    assert Map.has_key?(gas_info, :propose_gas_price)
    assert Map.has_key?(gas_info, :fast_gas_price)
    assert Map.has_key?(gas_info, :suggest_base_fee)
    assert Map.has_key?(gas_info, :gas_used_ratio)
    assert Map.has_key?(gas_info, :last_block)

    # The gas prices should be numeric values
    assert is_number(gas_info.safe_gas_price)
    assert is_number(gas_info.propose_gas_price)
    assert is_number(gas_info.fast_gas_price)
    assert is_number(gas_info.suggest_base_fee)

    # The last block should be an integer
    assert is_integer(gas_info.last_block)
  end

  test "fails when no auth is provided" do
    # The NoAuthGasOracleLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthGasOracleLens, :focus, [%{chainid: 1}])

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        assert String.contains?(error_message, "Missing/Invalid API Key")

      {:ok, %{"message" => message}} when is_binary(message) ->
        # The API might return a message about missing/invalid API key
        assert String.contains?(message, "Missing/Invalid API Key")


      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil
    end
  end
end
