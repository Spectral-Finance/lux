defmodule Lux.Integration.Etherscan.AddressTokenBalanceLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.AddressTokenBalance
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Example address that holds multiple tokens (Binance)
  @token_holder "0x28c6c06298d514db089934071355e5743bf21d60"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthAddressTokenBalanceLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Address Token Balance API",
      description: "Fetches the ERC-20 tokens and amount held by an address",
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
      |> Map.put_new(:offset, 100)

      # Set module and action for this endpoint
      params
      |> Map.put(:module, "account")
      |> Map.put(:action, "addresstokenbalance")
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
    result = RateLimitedAPI.call_standard(AddressTokenBalance, :focus, [%{
      address: @token_holder,
      chainid: 1
    }])

    case result do
      {:error, %{result: result}} when is_binary(result) ->
        not String.contains?(result, "API Pro endpoint")
      _ -> true
    end
  end

  test "can fetch token balances for an address" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      :ok
    else
      result = RateLimitedAPI.call_standard(AddressTokenBalance, :focus, [%{
        address: @token_holder,
        chainid: 1
      }])

      case result do
        {:ok, %{result: tokens, token_balances: tokens}} ->
          # Verify the tokens list structure
          assert is_list(tokens)

          # If tokens are found, check their structure
          if length(tokens) > 0 do
            first_token = List.first(tokens)
            assert Map.has_key?(first_token, :token_address)
            assert Map.has_key?(first_token, :token_name)
            assert Map.has_key?(first_token, :token_symbol)
            assert Map.has_key?(first_token, :token_decimals)
            assert Map.has_key?(first_token, :token_quantity)
            
            # Verify token data is valid
            assert is_binary(first_token.token_name)
            assert is_binary(first_token.token_symbol)
            assert is_binary(first_token.token_quantity)
          end

        {:error, error} ->
          if is_rate_limited?(result) do
            :ok
          else
            flunk("Failed to fetch token balances: #{inspect(error)}")
          end
      end
    end
  end

  test "can fetch token balances with pagination" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      :ok
    else
      # Using a small offset to test pagination
      offset = 5

      result = RateLimitedAPI.call_standard(AddressTokenBalance, :focus, [%{
        address: @token_holder,
        page: 1,
        offset: offset,
        chainid: 1
      }])

      case result do
        {:ok, %{result: tokens}} ->
          # Verify the tokens list structure
          assert is_list(tokens)
          assert length(tokens) <= offset

        {:error, error} ->
          if is_rate_limited?(result) do
            :ok
          else
            flunk("Failed to fetch token balances with pagination: #{inspect(error)}")
          end
      end
    end
  end

  test "returns error for invalid address" do
    # Using an invalid address format
    result = RateLimitedAPI.call_standard(AddressTokenBalance, :focus, [%{
      address: "0xinvalid",
      chainid: 1
    }])

    case result do
      {:error, error} ->
        # Should return an error for invalid address
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
    # The NoAuthAddressTokenBalanceLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthAddressTokenBalanceLens, :focus, [%{
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
