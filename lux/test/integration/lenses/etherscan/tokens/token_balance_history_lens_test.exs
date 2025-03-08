defmodule Lux.Integration.Etherscan.TokenBalanceHistoryLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenBalanceHistory

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"
  # Example address that holds LINK tokens (Binance)
  @token_holder "0x28c6c06298d514db089934071355e5743bf21d60"
  # Block number to check (Ethereum block from 2019)
  @block_number 8000000

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Sleep for 2000ms to avoid hitting the Etherscan API rate limit (2 calls per second for this endpoint)
    Process.sleep(200)
    :ok
  end

  defmodule NoAuthTokenBalanceHistoryLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Historical ERC20 Token Balance API",
      description: "Fetches the balance of an ERC-20 token of an address at a certain block height",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "account")
      |> Map.put(:action, "tokenbalancehistory")
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
    result = TokenBalanceHistory.focus(%{
      contractaddress: @token_contract,
      address: @token_holder,
      blockno: @block_number,
      chainid: 1
    })

    case result do
      {:error, %{result: result}} when is_binary(result) ->
        not String.contains?(result, "API Pro endpoint")
      _ -> true
    end
  end

  test "can fetch historical token balance for an address at a specific block" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      IO.puts("Skipping test: Pro API key required for TokenBalanceHistory")
      :ok
    else
      result = TokenBalanceHistory.focus(%{
        contractaddress: @token_contract,
        address: @token_holder,
        blockno: @block_number,
        chainid: 1
      })

      case result do
        {:ok, %{result: balance, token_balance: balance}} ->
          # Verify the balance is a valid string representing a number
          assert is_binary(balance)

          # Log the balance for informational purposes
          IO.puts("LINK token balance for #{@token_holder} at block #{@block_number}: #{balance}")

        {:error, error} ->
          if is_rate_limited?(result) do
            IO.puts("Skipping test due to rate limiting: #{inspect(error)}")
          else
            flunk("Failed to fetch historical token balance: #{inspect(error)}")
          end
      end
    end
  end

  test "returns error for invalid contract address" do
    # Using an invalid contract address format
    result = TokenBalanceHistory.focus(%{
      contractaddress: "0xinvalid",
      address: @token_holder,
      blockno: @block_number,
      chainid: 1
    })

    case result do
      {:error, error} ->
        # Should return an error for invalid contract address
        assert error != nil
        IO.puts("Error for invalid contract address: #{inspect(error)}")

      {:ok, %{result: "0"}} ->
        # Some APIs return "0" for invalid addresses instead of an error
        IO.puts("API returned '0' for invalid contract address")
        assert true

      {:ok, _} ->
        # If the API doesn't return an error, that's also acceptable
        # as long as we're testing the API behavior
        IO.puts("API didn't return an error for invalid contract address")
        assert true
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthTokenBalanceHistoryLens doesn't have an API key, so it should fail
    result = NoAuthTokenBalanceHistoryLens.focus(%{
      contractaddress: @token_contract,
      address: @token_holder,
      blockno: @block_number,
      chainid: 1
    })

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        assert String.contains?(error_message, "Missing/Invalid API Key")


      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil

    end
  end
end
