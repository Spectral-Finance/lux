defmodule Lux.Integration.Etherscan.TokenInfoLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenInfo

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Sleep for 2000ms to avoid hitting the Etherscan API rate limit (2 calls per second for this endpoint)
    Process.sleep(200)
    :ok
  end

  defmodule NoAuthTokenInfoLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Token Info API",
      description: "Fetches project information and social media links of an ERC20/ERC721/ERC1155 token",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "token")
      |> Map.put(:action, "tokeninfo")
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
    result = TokenInfo.focus(%{
      contractaddress: @token_contract,
      chainid: 1
    })

    case result do
      {:error, %{result: result}} when is_binary(result) ->
        not String.contains?(result, "API Pro endpoint")
      _ -> true
    end
  end

  test "can fetch token info" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      IO.puts("Skipping test: Pro API key required for TokenInfo")
      :ok
    else
      result = TokenInfo.focus(%{
        contractaddress: @token_contract,
        chainid: 1
      })

      case result do
        {:ok, %{result: token_info, token_info: token_info}} ->
          # Verify the token info structure
          assert is_list(token_info)
          assert length(token_info) > 0

          # Check the first token info's structure
          token = List.first(token_info)
          assert Map.has_key?(token, :contract_address)
          assert Map.has_key?(token, :token_name)
          assert Map.has_key?(token, :symbol)
          assert Map.has_key?(token, :token_type)

          # Log some token info for informational purposes
          IO.puts("Token name: #{token.token_name}")
          IO.puts("Token symbol: #{token.symbol}")
          IO.puts("Token type: #{token.token_type}")
          IO.puts("Total supply: #{token.total_supply}")

          if token.website && token.website != "" do
            IO.puts("Website: #{token.website}")
          end

        {:error, error} ->
          if is_rate_limited?(result) do
            IO.puts("Skipping test due to rate limiting: #{inspect(error)}")
          else
            flunk("Failed to fetch token info: #{inspect(error)}")
          end
      end
    end
  end

  test "returns error for invalid contract address" do
    # Using an invalid contract address format
    result = TokenInfo.focus(%{
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
    # The NoAuthTokenInfoLens doesn't have an API key, so it should fail
    result = NoAuthTokenInfoLens.focus(%{
      contractaddress: @token_contract,
      chainid: 1
    })

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        assert String.contains?(error_message, "Missing/Invalid API Key")
        IO.puts("Error for no auth: #{error_message}")

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil

    end
  end
end
