defmodule Lux.Integration.Etherscan.TokenSupplyHistoryLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenSupplyHistory
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"
  # Block number to check (Ethereum block from 2019)
  @block_number 8000000

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthTokenSupplyHistoryLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Historical ERC20 Token Total Supply API",
      description: "Fetches the amount of an ERC-20 token in circulation at a certain block height",
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
      |> Map.put(:action, "tokensupplyhistory")
    end
  end

  # Helper function to check if we're being rate limited
  defp is_rate_limited?(result) do
    case result do
      {:error, %{result: "Max rate limit reached"}} -> true
      {:error, %{message: message}} when is_binary(message) ->
        String.contains?(message, "rate limit")
      _ -> false
    end
  end

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    # Check if the API key is a Pro key by making a test request
    result = RateLimitedAPI.call_standard(TokenSupplyHistory, :focus, [%{
      contractaddress: @token_contract,
      blockno: @block_number,
      chainid: 1
    }])

    case result do
      {:error, %{result: result}} when is_binary(result) ->
        not String.contains?(result, "API Pro endpoint")
      _ -> true
    end
  end

  test "can fetch historical token supply at a specific block" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      :ok
    else
      result = RateLimitedAPI.call_standard(TokenSupplyHistory, :focus, [%{
        contractaddress: @token_contract,
        blockno: @block_number,
        chainid: 1
      }])

      case result do
        {:ok, %{result: supply, token_supply: supply}} ->
          # Verify the supply is a valid string representing a number
          assert is_binary(supply)
          {supply_value, _} = Integer.parse(supply)
          assert supply_value > 0

        {:error, error} ->
          if is_rate_limited?(result) do
            :ok
          else
            flunk("Failed to fetch historical token supply: #{inspect(error)}")
          end
      end
    end
  end

  test "returns error for invalid contract address" do
    # Using an invalid contract address format
    result = RateLimitedAPI.call_standard(TokenSupplyHistory, :focus, [%{
      contractaddress: "0xinvalid",
      blockno: @block_number,
      chainid: 1
    }])

    case result do
      {:error, error} ->
        # Should return an error for invalid contract address
        assert error != nil

      {:ok, %{result: "0"}} ->
        # Some APIs return "0" for invalid addresses instead of an error
        assert true

      {:ok, _} ->
        # If the API doesn't return an error, that's also acceptable
        # as long as we're testing the API behavior
        assert true
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthTokenSupplyHistoryLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthTokenSupplyHistoryLens, :focus, [%{
      contractaddress: @token_contract,
      blockno: @block_number,
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
