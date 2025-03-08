defmodule Lux.Integration.TransposePriceLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.TransposePriceLens

  # UNI token
  @uni "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984"
  # AAVE token
  @aave "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9"

  defmodule NoAuthTransposeLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Transpose Token Price API",
      description: "Fetches historical token prices from Transpose",
      url: "https://api.transpose.io/prices/price",
      method: :get
  end

  test "can fetch single token price from Transpose API" do
    assert {:ok, %{prices: [price | _]}} =
             TransposePriceLens.focus(%{
               token_addresses: [@uni],
               timestamp: DateTime.to_iso8601(DateTime.utc_now())
             })

    assert is_number(price.price)
    assert price.token_symbol == "UNI"
  end

  test "can fetch multiple token prices from Transpose API" do
    assert {:ok, %{prices: prices}} =
             TransposePriceLens.focus(%{
               token_addresses: [@uni, @aave],
               timestamp: DateTime.to_iso8601(DateTime.utc_now())
             })

    assert length(prices) == 2

    # Find UNI and AAVE in the results
    uni_price = Enum.find(prices, &(&1.token_symbol == "UNI"))
    aave_price = Enum.find(prices, &(&1.token_symbol == "AAVE"))

    assert uni_price, "UNI token price not found in response"
    assert aave_price, "AAVE token price not found in response"
    assert is_number(uni_price.price)
    assert is_number(aave_price.price)
  end

  test "fails when no auth is provided" do
    assert {:error, _} =
             NoAuthTransposeLens.focus(%{
               token_addresses: @uni,
               timestamp: DateTime.to_iso8601(DateTime.utc_now())
             })
  end
end
