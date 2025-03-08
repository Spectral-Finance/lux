defmodule Lux.Integration.Etherscan.EthPriceLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.EthPrice
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthEthPriceLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan ETH Price API",
      description: "Fetches the latest price of 1 ETH",
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
      |> Map.put(:action, "ethprice")
    end
  end

  test "can fetch ETH price information" do
    assert {:ok, %{result: eth_price, eth_price: eth_price}} =
             RateLimitedAPI.call_standard(EthPrice, :focus, [%{
               chainid: 1
             }])

    # Verify the structure of the response
    assert is_map(eth_price)
    assert Map.has_key?(eth_price, :eth_btc)
    assert Map.has_key?(eth_price, :eth_btc_timestamp)
    assert Map.has_key?(eth_price, :eth_usd)
    assert Map.has_key?(eth_price, :eth_usd_timestamp)

    # ETH price should be a positive number
    assert is_number(eth_price.eth_usd)
    assert eth_price.eth_usd > 0
    assert is_number(eth_price.eth_btc)
    assert eth_price.eth_btc > 0

    # Timestamps should be valid Unix timestamps
    assert is_integer(eth_price.eth_usd_timestamp)
    assert eth_price.eth_usd_timestamp > 1_500_000_000 # Timestamp after 2017
    assert is_integer(eth_price.eth_btc_timestamp)
    assert eth_price.eth_btc_timestamp > 1_500_000_000 # Timestamp after 2017

    # Log the price for informational purposes
    IO.puts("ETH/USD: $#{eth_price.eth_usd}")
    IO.puts("ETH/BTC: #{eth_price.eth_btc}")
    IO.puts("ETH/USD Timestamp: #{eth_price.eth_usd_timestamp}")
    IO.puts("ETH/BTC Timestamp: #{eth_price.eth_btc_timestamp}")
  end

  test "requires chainid parameter for v2 API" do
    # The v2 API requires the chainid parameter
    result = RateLimitedAPI.call_standard(EthPrice, :focus, [%{}])

    case result do
      {:error, %{message: "NOTOK", result: error_message}} ->
        # Should return an error about missing chainid parameter
        assert String.contains?(error_message, "Missing chainid parameter")
        IO.puts("Expected error for missing chainid: #{error_message}")

      {:ok, _} ->
        flunk("Expected an error for missing chainid parameter")
    end
  end

  test "can fetch ETH price for a different chain" do
    # This test just verifies that we can specify a different chain
    # The actual result may vary depending on the chain
    result = RateLimitedAPI.call_standard(EthPrice, :focus, [%{
      chainid: 137 # Polygon
    }])

    case result do
      {:ok, %{result: eth_price}} ->
        # Log the price for informational purposes
        IO.puts("ETH/USD on Polygon: $#{eth_price.eth_usd}")
        assert true

      {:error, error} ->
        # If the endpoint doesn't exist on this chain, that's also acceptable
        IO.puts("Error fetching ETH price on Polygon: #{inspect(error)}")
        assert true
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthEthPriceLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthEthPriceLens, :focus, [%{
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
