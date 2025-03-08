defmodule Lux.Integration.Etherscan.GasEstimateLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.GasEstimate
  alias Lux.Lenses.Etherscan.GasOracle
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthGasEstimateLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Gas Estimate API",
      description: "Fetches the estimated time, in seconds, for a transaction to be confirmed on the blockchain",
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
      |> Map.put(:action, "gasestimate")
      # Ensure chainid is passed through
      |> Map.put_new(:chainid, Map.get(params, :chainid, 1))
    end
  end

  test "can fetch estimated confirmation time for a transaction" do
    # Using a sample gas price of 2 Gwei (2000000000 wei)
    gas_price = 2000000000

    # Always include chainid parameter for v2 API
    assert {:ok, %{result: estimated_seconds}} =
             RateLimitedAPI.call_standard(GasEstimate, :focus, [%{
               gasprice: gas_price,
               chainid: 1
             }])

    # Verify the result is a number (integer)
    assert is_integer(estimated_seconds)

    # The estimated time should be a positive number
    assert estimated_seconds >= 0

    # Log the estimated confirmation time for informational purposes
    IO.puts("Estimated confirmation time for gas price #{gas_price} wei: #{estimated_seconds} seconds")
    IO.puts("That's approximately #{estimated_seconds / 60} minutes")
  end

  test "can fetch estimated confirmation time with current fast gas price" do
    # First, get the current fast gas price from the gas oracle
    # Always include chainid parameter for v2 API
    {:ok, %{result: gas_info}} = RateLimitedAPI.call_standard(GasOracle, :focus, [%{chainid: 1}])

    # Convert the fast gas price from Gwei to wei (1 Gwei = 10^9 wei)
    fast_gas_price_wei = trunc(gas_info.fast_gas_price * 1_000_000_000)

    # Now get the estimated confirmation time for this gas price
    # Always include chainid parameter for v2 API
    assert {:ok, %{result: estimated_seconds}} =
             RateLimitedAPI.call_standard(GasEstimate, :focus, [%{
               gasprice: fast_gas_price_wei,
               chainid: 1
             }])

    # Verify the result is a number (integer)
    assert is_integer(estimated_seconds)

    # The estimated time should be a positive number
    assert estimated_seconds >= 0

    # Log the estimated confirmation time for informational purposes
    IO.puts("Current fast gas price: #{gas_info.fast_gas_price} Gwei (#{fast_gas_price_wei} wei)")
    IO.puts("Estimated confirmation time: #{estimated_seconds} seconds")
    IO.puts("That's approximately #{estimated_seconds / 60} minutes")
  end

  test "can fetch estimated confirmation time for a specific chain" do
    # Using a sample gas price of 2 Gwei (2000000000 wei) on Ethereum mainnet
    gas_price = 2000000000
    chain_id = 1

    assert {:ok, %{result: estimated_seconds}} =
             RateLimitedAPI.call_standard(GasEstimate, :focus, [%{
               gasprice: gas_price,
               chainid: chain_id
             }])

    # Verify the result is a number (integer)
    assert is_integer(estimated_seconds)

    # The estimated time should be a positive number
    assert estimated_seconds >= 0

    # Log the estimated confirmation time for informational purposes
    IO.puts("Estimated confirmation time on chain #{chain_id} for gas price #{gas_price} wei: #{estimated_seconds} seconds")
    IO.puts("That's approximately #{estimated_seconds / 60} minutes")
  end

  test "can handle extreme gas price values" do
    # Using an extremely low gas price (0 wei)
    # Note: The API might accept this and return a valid result or an error
    zero_gas_price = 0

    # Always include chainid parameter for v2 API
    result = RateLimitedAPI.call_standard(GasEstimate, :focus, [%{
      gasprice: zero_gas_price,
      chainid: 1
    }])

    case result do
      {:ok, %{result: estimated_seconds}} when is_integer(estimated_seconds) ->
        # If the API accepts the zero gas price, it might return a very high confirmation time
        IO.puts("Estimated confirmation time for zero gas price: #{estimated_seconds} seconds")
        IO.puts("That's approximately #{estimated_seconds / 60} minutes")
        assert estimated_seconds >= 0

      {:ok, %{result: error_message}} when is_binary(error_message) ->
        # The API might return an error message as the result
        IO.puts("Error message for zero gas price: #{error_message}")
        assert String.length(error_message) > 0

      {:error, error} ->
        # Or it might return an error tuple
        IO.puts("Error for zero gas price: #{inspect(error)}")
        assert error != nil
    end

    # Using an extremely high gas price (1000 Gwei = 1000000000000 wei)
    high_gas_price = 1000000000000

    # Always include chainid parameter for v2 API
    high_result = RateLimitedAPI.call_standard(GasEstimate, :focus, [%{
      gasprice: high_gas_price,
      chainid: 1
    }])

    case high_result do
      {:ok, %{result: estimated_seconds}} when is_integer(estimated_seconds) ->
        # If the API accepts the high gas price, it should return a very low confirmation time
        IO.puts("Estimated confirmation time for high gas price (1000 Gwei): #{estimated_seconds} seconds")
        assert estimated_seconds >= 0

      {:ok, %{result: error_message}} when is_binary(error_message) ->
        # The API might return an error message as the result
        IO.puts("Error message for high gas price: #{error_message}")
        assert String.length(error_message) > 0

      {:error, error} ->
        # Or it might return an error tuple
        IO.puts("Error for high gas price: #{inspect(error)}")
        assert error != nil
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthGasEstimateLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthGasEstimateLens, :focus, [%{
      gasprice: 2000000000,
      chainid: 1
    }])

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
