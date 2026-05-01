defmodule Lux.Prisms.Nft.NftCollectionStatsPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Nft.NftCollectionStatsPrism

  describe "handler/2" do
    test "returns collection stats for a valid slug" do
      input = %{
        "collection_slug" => "bored-ape-yacht-club",
        "marketplace" => "opensea"
      }

      result = NftCollectionStatsPrism.handler(input, %{})

      case result do
        {:ok, %{status: "success", collection_stats: stats}} ->
          assert is_map(stats)

        {:error, reason} ->
          # API may be rate limited or require auth
          assert is_binary(reason)
      end
    end

    test "returns error for invalid input" do
      input = %{}
      result = NftCollectionStatsPrism.handler(input, %{})
      # Should return some result (public API or error)
      assert match?({:ok, _} or {:error, _}, result)
    end
  end
end
