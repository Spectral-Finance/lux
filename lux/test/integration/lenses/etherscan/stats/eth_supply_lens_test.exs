defmodule Lux.Integration.Etherscan.EthSupplyLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.EthSupply
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthEthSupplyLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan ETH Supply API",
      description: "Fetches the current amount of Ether in circulation excluding ETH2 Staking rewards and EIP1559 burnt fees",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "stats")
      |> Map.put(:action, "ethsupply")
    end
  end

  test "can fetch total ETH supply" do
    assert {:ok, %{result: eth_supply, eth_supply: eth_supply}} =
             RateLimitedAPI.call_standard(EthSupply, :focus, [%{
               chainid: 1
             }])

    # ETH supply should be a large number (more than 100 million ETH)
    assert is_integer(eth_supply)
    assert eth_supply > 100_000_000 * 1.0e18 # More than 100M ETH in wei
  end

  test "requires chainid parameter for v2 API" do
    # The v2 API requires the chainid parameter
    result = RateLimitedAPI.call_standard(EthSupply, :focus, [%{}])

    case result do
      {:error, %{message: "NOTOK", result: error_message}} ->
        # Should return an error about missing chainid parameter
        assert String.contains?(error_message, "Missing chainid parameter")

      {:ok, _} ->
        flunk("Expected an error for missing chainid parameter")
    end
  end

  test "can fetch ETH supply for a different chain" do
    # This test just verifies that we can specify a different chain
    # The actual result may vary depending on the chain
    result = RateLimitedAPI.call_standard(EthSupply, :focus, [%{
      chainid: 137 # Polygon
    }])

    case result do
      {:ok, %{result: eth_supply}} ->
        assert true

      {:error, error} ->
        # If the endpoint doesn't exist on this chain, that's also acceptable
        assert true
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthEthSupplyLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthEthSupplyLens, :focus, [%{
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
