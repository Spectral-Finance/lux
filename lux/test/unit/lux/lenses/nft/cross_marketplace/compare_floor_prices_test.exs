defmodule Lux.Lenses.NFT.CrossMarketplace.CompareFloorPricesTest do
  @moduledoc """
  Test suite for the CompareFloorPrices cross-marketplace lens.
  Verifies:
  - Aggregation of floor prices from OpenSea and Blur
  - Best floor price selection (lowest ask)
  - Price spread calculation
  - Partial availability (one marketplace unavailable)
  - Both marketplaces unavailable
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.NFT.CrossMarketplace.CompareFloorPrices

  @collection_slug "boredapeyachtclub"
  @contract "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "aggregates floor prices from both marketplaces" do
      # OpenSea response (higher price)
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "collection" => @collection_slug,
          "name" => "Bored Ape Yacht Club",
          "stats" => %{
            "floor_price" => 10.5,
            "floor_price_symbol" => "ETH",
            "total_supply" => 10000,
            "num_owners" => 5432,
            "one_day_volume" => 234.56
          }
        }))
      end)

      # Blur response (lower price — should win)
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "collection" => %{
            "contractAddress" => @contract,
            "name" => "Bored Ape Yacht Club",
            "floorAsk" => %{"amount" => "10.1", "currency" => "ETH"},
            "stats" => %{
              "numOwners" => 5400,
              "volume24h" => "156.7"
            }
          }
        }))
      end)

      assert {:ok, result} = CompareFloorPrices.focus(
        %{"collection_slug" => @collection_slug, "contract_address" => @contract},
        %{}
      )

      assert result.collection_slug == @collection_slug
      assert result.contract_address == @contract
      assert result.best_floor_price == 10.1
      assert result.best_floor_marketplace == "blur"
      assert result.currency == "ETH"
      assert result.marketplaces.opensea.available == true
      assert result.marketplaces.blur.available == true
      assert result.marketplaces.opensea.floor_price == 10.5
      assert result.marketplaces.blur.floor_price == 10.1
      assert_in_delta result.price_spread, 0.4, 0.001
    end

    test "handles OpenSea unavailable, returns Blur price" do
      # OpenSea returns error
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(503, Jason.encode!(%{
          "detail" => "Service unavailable"
        }))
      end)

      # Blur returns valid data
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "collection" => %{
            "contractAddress" => @contract,
            "name" => "Bored Ape Yacht Club",
            "floorAsk" => %{"amount" => "9.8", "currency" => "ETH"},
            "stats" => %{}
          }
        }))
      end)

      assert {:ok, result} = CompareFloorPrices.focus(
        %{"collection_slug" => @collection_slug, "contract_address" => @contract},
        %{}
      )

      assert result.best_floor_price == 9.8
      assert result.best_floor_marketplace == "blur"
      assert result.marketplaces.opensea.available == false
      assert result.marketplaces.blur.available == true
    end

    test "handles Blur unavailable, returns OpenSea price" do
      # OpenSea returns valid data
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "collection" => @collection_slug,
          "stats" => %{
            "floor_price" => 11.2,
            "floor_price_symbol" => "ETH"
          }
        }))
      end)

      # Blur returns error
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Collection not found"
        }))
      end)

      assert {:ok, result} = CompareFloorPrices.focus(
        %{"collection_slug" => @collection_slug, "contract_address" => @contract},
        %{}
      )

      assert result.best_floor_price == 11.2
      assert result.best_floor_marketplace == "opensea"
      assert result.marketplaces.opensea.available == true
      assert result.marketplaces.blur.available == false
    end

    test "handles both marketplaces unavailable" do
      # OpenSea error
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(503, Jason.encode!(%{"detail" => "Service unavailable"}))
      end)

      # Blur error
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(503, Jason.encode!(%{"message" => "Service unavailable"}))
      end)

      assert {:ok, result} = CompareFloorPrices.focus(
        %{"collection_slug" => @collection_slug, "contract_address" => @contract},
        %{}
      )

      assert result.marketplaces.opensea.available == false
      assert result.marketplaces.blur.available == false
      refute Map.has_key?(result, :best_floor_price)
      refute Map.has_key?(result, :price_spread)
    end
  end
end
