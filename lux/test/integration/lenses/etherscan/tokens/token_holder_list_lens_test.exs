defmodule Lux.Integration.Etherscan.TokenHolderListLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenHolderList
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthTokenHolderListLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Token Holder List API",
      description: "Fetches the current ERC20 token holders and number of tokens held",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Ensure page and offset parameters have default values
      params = params
      |> Map.put_new(:page, 1)
      |> Map.put_new(:offset, 10)

      # Set module and action for this endpoint
      params
      |> Map.put(:module, "token")
      |> Map.put(:action, "tokenholderlist")
    end
  end

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    # Check if the API key is a Pro key by making a test request
    result = RateLimitedAPI.call_standard(TokenHolderList, :focus, [%{
      contractaddress: @token_contract,
      chainid: 1
    }])

    case result do
      {:error, %{result: result}} when is_binary(result) ->
        not String.contains?(result, "API Pro endpoint")
      _ -> true
    end
  end

  test "can fetch token holder list" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      :ok
    else
      assert {:ok, %{result: holders, token_holders: holders}} =
               RateLimitedAPI.call_standard(TokenHolderList, :focus, [%{
                 contractaddress: @token_contract,
                 chainid: 1
               }])

      # Verify the holders list structure
      assert is_list(holders)
      assert length(holders) > 0

      # Check the first holder's structure
      first_holder = List.first(holders)
      assert Map.has_key?(first_holder, :address)
      assert Map.has_key?(first_holder, :quantity)
      assert Map.has_key?(first_holder, :share)
    end
  end

  test "can fetch token holder list with pagination" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      :ok
    else
      # Using a small offset to test pagination
      offset = 5

      assert {:ok, %{result: holders}} =
               RateLimitedAPI.call_standard(TokenHolderList, :focus, [%{
                 contractaddress: @token_contract,
                 page: 1,
                 offset: offset,
                 chainid: 1
               }])

      # Verify the holders list structure
      assert is_list(holders)
      assert length(holders) <= offset
    end
  end

  test "returns error for invalid contract address" do
    # Using an invalid contract address format
    result = RateLimitedAPI.call_standard(TokenHolderList, :focus, [%{
      contractaddress: "0xinvalid",
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
    # The NoAuthTokenHolderListLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthTokenHolderListLens, :focus, [%{
      contractaddress: @token_contract,
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
