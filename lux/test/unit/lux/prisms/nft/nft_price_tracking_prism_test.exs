defmodule Lux.Prisms.Nft.NftPriceTrackingPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Nft.NftPriceTrackingPrism

  describe "handler/2" do
    test "returns price history for a valid collection" do
      input = %{
        "collection_slug" => "bored-ape-yacht-club",
        "period" => "7d"
      }

      result = NftPriceTrackingPrism.handler(input, %{})

      case result do
        {:ok, %{status: "success", price_history: history}} ->
          assert is_list(history)

        {:error, reason} ->
          assert is_binary(reason)
      end
    end
  end
end
