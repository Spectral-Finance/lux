defmodule Lux.Integration.Etherscan.BalanceHistoryLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.BalanceHistory
  alias Lux.Lenses.Etherscan.Base
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Ethereum Foundation address
  @eth_foundation "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe"
  # Block number to check (Ethereum block from 2019)
  @block_number 8000000

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_pro_api()
    :ok
  end

  defmodule NoAuthBalanceHistoryLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Historical ETH Balance API",
      description: "Fetches historical ETH balance for an Ethereum address at a specific block",
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
      |> Map.put(:action, "balancehistory")
    end
  end

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    case Base.check_pro_endpoint("account", "balancehistory") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch historical ETH balance for an address at a specific block" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      IO.puts("Skipping test: Pro API key required for BalanceHistory")
      :ok
    else
      assert {:ok, %{result: balance}} =
               RateLimitedAPI.call_pro(BalanceHistory, :focus, [%{
                 address: @eth_foundation,
                 blockno: @block_number,
                 chainid: 1
               }])

      # Convert balance from wei to ether for easier validation
      balance_in_eth = String.to_integer(balance) / 1.0e18

      # The Ethereum Foundation should have had some ETH at this block
      assert is_binary(balance)
      assert balance_in_eth > 0

      # Log the balance for informational purposes
      IO.puts("Ethereum Foundation's balance at block #{@block_number}: #{balance_in_eth} ETH")
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthBalanceHistoryLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_pro(NoAuthBalanceHistoryLens, :focus, [%{
      address: @eth_foundation,
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

  test "raises error when trying to use without Pro API key" do
    # Skip this test if we actually have a Pro API key
    if has_pro_api_key?() do
      IO.puts("Skipping test: We have a Pro API key, so this test is not applicable")
      :ok
    else
      # This should raise an ArgumentError because we don't have a Pro API key
      assert_raise ArgumentError, fn ->
        RateLimitedAPI.call_pro(BalanceHistory, :focus, [%{
          address: @eth_foundation,
          blockno: @block_number,
          chainid: 1
        }])
      end
    end
  end
end
