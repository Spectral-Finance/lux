defmodule Lux.Prisms.Nft.NftListingManagerPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Nft.NftListingManagerPrism

  describe "handler/2" do
    test "returns listings for a valid collection" do
      input = %{
        "collection_slug" => "bored-ape-yacht-club",
        "max_price" => 100.0,
        "limit" => 5
      }

      result = NftListingManagerPrism.handler(input, %{})

      case result do
        {:ok, %{status: "success", listings: listings}} ->
          assert is_list(listings)

        {:error, reason} ->
          assert is_binary(reason)
      end
    end
  end
end
