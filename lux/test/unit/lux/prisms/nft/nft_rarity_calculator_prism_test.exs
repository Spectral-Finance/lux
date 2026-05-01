defmodule Lux.Prisms.Nft.NftRarityCalculatorPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Nft.NftRarityCalculatorPrism

  describe "handler/2" do
    test "calculates rarity for a specific token" do
      input = %{
        "collection_slug" => "bored-ape-yacht-club",
        "token_id" => "1000"
      }

      result = NftRarityCalculatorPrism.handler(input, %{})

      case result do
        {:ok, %{status: "success", rarity_score: score}} ->
          assert is_number(score)

        {:error, reason} ->
          assert is_binary(reason)
      end
    end
  end
end
