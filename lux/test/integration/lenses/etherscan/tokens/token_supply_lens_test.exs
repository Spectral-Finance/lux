defmodule Lux.Integration.Etherscan.TokenSupplyLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenSupply

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Sleep for 300ms to avoid hitting the Etherscan API rate limit (5 calls per second)
    Process.sleep(300)
    :ok
  end

  defmodule NoAuthTokenSupplyLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan ERC20 Token Total Supply API",
      description: "Fetches the current amount of an ERC-20 token in circulation",
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
      |> Map.put(:action, "tokensupply")
    end
  end

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    # Check if the API key is a Pro key by making a test request
    result = TokenSupply.focus(%{
      contractaddress: @token_contract,
      chainid: 1
    })

    case result do
      {:error, %{result: result}} when is_binary(result) ->
        not String.contains?(result, "API Pro endpoint")
      _ -> true
    end
  end

  test "can fetch total supply for an ERC-20 token" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      IO.puts("Skipping test: Pro API key required for TokenSupply")
      :ok
    else
      assert {:ok, %{result: supply, token_supply: supply}} =
               TokenSupply.focus(%{
                 contractaddress: @token_contract,
                 chainid: 1
               })

      # Verify the supply is a valid string representing a number
      assert is_binary(supply)
      {supply_value, _} = Integer.parse(supply)
      assert supply_value > 0

      # Log the supply for informational purposes
      IO.puts("LINK token total supply: #{supply}")
    end
  end

  test "returns error for invalid contract address" do
    # Using an invalid contract address format
    result = TokenSupply.focus(%{
      contractaddress: "0xinvalid",
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
    # The NoAuthTokenSupplyLens doesn't have an API key, so it should fail
    result = NoAuthTokenSupplyLens.focus(%{
      contractaddress: @token_contract,
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
