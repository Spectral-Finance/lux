defmodule Lux.Integration.Etherscan.BalanceMultiLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.BalanceMulti
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Vitalik's address
  @vitalik "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  # Ethereum Foundation address
  @eth_foundation "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthBalanceMultiLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan ETH Balance Multi API",
      description: "Fetches ETH balances for multiple Ethereum addresses",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Convert addresses array to comma-separated string
      address_string = Enum.join(params.addresses, ",")

      # Set module and action for this endpoint
      params
      |> Map.delete(:addresses)  # Remove the addresses list to avoid URI encoding issues
      |> Map.put(:module, "account")
      |> Map.put(:action, "balancemulti")
      |> Map.put(:address, address_string)
    end
  end

  test "can fetch ETH balances for multiple addresses" do
    assert {:ok, %{result: balances}} =
             RateLimitedAPI.call_standard(BalanceMulti, :focus, [%{
               addresses: [@vitalik, @eth_foundation],
               chainid: 1
             }])

    # Verify we got results for both addresses
    assert length(balances) == 2

    # Find Vitalik's and Ethereum Foundation's balances
    vitalik_balance = Enum.find(balances, &(&1["account"] == @vitalik))
    eth_foundation_balance = Enum.find(balances, &(&1["account"] == @eth_foundation))

    # Verify both balances were found
    assert vitalik_balance, "Vitalik's balance not found in response"
    assert eth_foundation_balance, "Ethereum Foundation's balance not found in response"

    # Convert balances from wei to ether for easier validation
    vitalik_balance_in_eth = String.to_integer(vitalik_balance["balance"]) / 1.0e18
    eth_foundation_balance_in_eth = String.to_integer(eth_foundation_balance["balance"]) / 1.0e18

    # Both addresses should have some ETH (more than 0)
    assert vitalik_balance_in_eth > 0
    assert eth_foundation_balance_in_eth > 0

    # Log the balances for informational purposes
    IO.puts("Vitalik's balance: #{vitalik_balance_in_eth} ETH")
    IO.puts("Ethereum Foundation's balance: #{eth_foundation_balance_in_eth} ETH")
  end

  test "can specify a different tag (block parameter)" do
    assert {:ok, %{result: balances}} =
             RateLimitedAPI.call_standard(BalanceMulti, :focus, [%{
               addresses: [@vitalik, @eth_foundation],
               chainid: 1,
               tag: "latest"
             }])

    assert length(balances) == 2
  end

  test "returns zero balance for invalid address format" do
    # Etherscan API should handle invalid addresses
    assert {:ok, %{result: balances}} =
             RateLimitedAPI.call_standard(BalanceMulti, :focus, [%{
               addresses: [@vitalik, "0xinvalid"],
               chainid: 1
             }])

    # We should still get results, but the invalid address should have 0 balance
    invalid_balance = Enum.find(balances, &(&1["account"] == "0xinvalid"))

    if invalid_balance do
      assert invalid_balance["balance"] == "0"
    else
      # If the API filters out invalid addresses, we should only have one result
      assert length(balances) == 1
      assert Enum.find(balances, &(&1["account"] == @vitalik))
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthBalanceMultiLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthBalanceMultiLens, :focus, [%{
      addresses: [@vitalik, @eth_foundation],
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
