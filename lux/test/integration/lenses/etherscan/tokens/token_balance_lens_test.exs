defmodule Lux.Integration.Etherscan.TokenBalanceLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenBalance
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"
  # Example address that holds LINK tokens (Binance)
  @token_holder "0x28c6c06298d514db089934071355e5743bf21d60"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthTokenBalanceLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan ERC20 Token Balance API",
      description: "Fetches the current balance of an ERC-20 token of an address",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Ensure tag parameter has a default value
      params = case params[:tag] do
        nil -> Map.put(params, :tag, "latest")
        _ -> params
      end

      # Set module and action for this endpoint
      params
      |> Map.put(:module, "account")
      |> Map.put(:action, "tokenbalance")
    end
  end

  @tag timeout: 120_000
  test "can fetch token balance for an address" do
    assert {:ok, %{result: balance, token_balance: balance}} =
             RateLimitedAPI.call_standard(TokenBalance, :focus, [%{
               contractaddress: @token_contract,
               address: @token_holder,
               chainid: 1
             }])

    # Verify the balance is a valid string representing a number
    assert is_binary(balance)
    {_balance_value, _} = Integer.parse(balance)
  end

  @tag timeout: 120_000
  test "can specify a different tag (block parameter)" do
    assert {:ok, %{result: _balance}} =
             RateLimitedAPI.call_standard(TokenBalance, :focus, [%{
               contractaddress: @token_contract,
               address: @token_holder,
               tag: "latest",
               chainid: 1
             }])
  end

  @tag timeout: 120_000
  test "returns zero balance for address with no tokens" do
    # Using a random address that likely doesn't hold the token
    random_address = "0x1111111111111111111111111111111111111111"

    assert {:ok, %{result: balance}} =
             RateLimitedAPI.call_standard(TokenBalance, :focus, [%{
               contractaddress: @token_contract,
               address: random_address,
               chainid: 1
             }])

    # Should return "0" for an address with no tokens
    assert balance == "0"
  end

  @tag timeout: 120_000
  test "returns error for invalid contract address" do
    # Using an invalid contract address format
    result = RateLimitedAPI.call_standard(TokenBalance, :focus, [%{
      contractaddress: "0xinvalid",
      address: @token_holder,
      chainid: 1
    }])

    case result do
      {:error, error} ->
        # Should return an error for invalid contract address
        assert error != nil

      _ ->
        flunk("Expected an error for invalid contract address")
    end
  end

  @tag timeout: 120_000
  test "fails when no auth is provided" do
    # The NoAuthTokenBalanceLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthTokenBalanceLens, :focus, [%{
      contractaddress: @token_contract,
      address: @token_holder,
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
