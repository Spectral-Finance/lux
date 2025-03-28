defmodule Lux.Integration.Etherscan.TokenBalanceLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenBalance
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"
  # Example address that holds LINK tokens (Binance)
  @token_holder "0x28c6c06298d514db089934071355e5743bf21d60"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  @tag timeout: 120_000
  test "can fetch token balance for an address" do
    assert {:ok, %{result: balance, token_balance: balance}} =
             TokenBalance.focus(%{
               contractaddress: @token_contract,
               address: @token_holder,
               chainid: 1
             })

    # Verify the balance is a valid string representing a number
    assert is_binary(balance)
    {_balance_value, _} = Integer.parse(balance)
  end

  @tag timeout: 120_000
  test "can specify a different tag (block parameter)" do
    assert {:ok, %{result: _balance}} =
             TokenBalance.focus(%{
               contractaddress: @token_contract,
               address: @token_holder,
               tag: "latest",
               chainid: 1
             })
  end

  @tag timeout: 120_000
  test "returns zero balance for address with no tokens" do
    # Using a random address that likely doesn't hold the token
    random_address = "0x1111111111111111111111111111111111111111"

    assert {:ok, %{result: balance}} =
             TokenBalance.focus(%{
               contractaddress: @token_contract,
               address: random_address,
               chainid: 1
             })

    # Should return "0" for an address with no tokens
    assert balance == "0"
  end
end
