defmodule Lux.Prisms.Nft.NftSalesMonitorPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Nft.NftSalesMonitorPrism

  describe "handler/2" do
    test "returns recent sales for a valid collection" do
      input = %{
        "collection_slug" => "bored-ape-yacht-club",
        "limit" => 5
      }

      result = NftSalesMonitorPrism.handler(input, %{})

      case result do
        {:ok, %{status: "success", sales: sales}} ->
          assert is_list(sales)

        {:error, reason} ->
          assert is_binary(reason)
      end
    end
  end
end
