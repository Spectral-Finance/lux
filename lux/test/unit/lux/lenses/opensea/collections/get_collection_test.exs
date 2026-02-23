defmodule Lux.Lenses.OpenSea.Collections.GetCollectionTest do
  @moduledoc """
  Test suite for the GetCollection module.
  These tests verify the lens's ability to:
  - Retrieve collection statistics from OpenSea
  - Handle optional fields gracefully
  - Propagate OpenSea API errors
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.OpenSea.Collections.GetCollection

  @collection_slug "boredapeyachtclub"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves collection with full stats" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v2/collections/#{@collection_slug}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "collection" => @collection_slug,
          "name" => "Bored Ape Yacht Club",
          "description" => "A limited NFT collection.",
          "image_url" => "https://example.com/image.png",
          "external_url" => "https://boredapeyachtclub.com",
          "stats" => %{
            "floor_price" => 10.5,
            "floor_price_symbol" => "ETH",
            "total_supply" => 10000,
            "num_owners" => 5432,
            "total_volume" => 987654.32,
            "one_day_volume" => 234.56,
            "seven_day_volume" => 1234.78,
            "thirty_day_volume" => 5678.9,
            "one_day_sales" => 15,
            "one_day_average_price" => 15.6,
            "market_cap" => 105000.0
          }
        }))
      end)

      assert {:ok, result} = GetCollection.focus(%{"collection_slug" => @collection_slug}, %{})

      assert result.collection == @collection_slug
      assert result.name == "Bored Ape Yacht Club"
      assert result.floor_price == 10.5
      assert result.floor_price_currency == "ETH"
      assert result.total_supply == 10000
      assert result.num_owners == 5432
      assert result.total_volume == 987654.32
      assert result.one_day_volume == 234.56
      assert result.seven_day_volume == 1234.78
    end

    test "successfully retrieves collection without optional stats" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "collection" => @collection_slug,
          "name" => "Test Collection",
          "stats" => %{
            "floor_price" => 0.1,
            "floor_price_symbol" => "ETH"
          }
        }))
      end)

      assert {:ok, result} = GetCollection.focus(%{"collection_slug" => @collection_slug}, %{})

      assert result.collection == @collection_slug
      assert result.name == "Test Collection"
      assert result.floor_price == 0.1
      refute Map.has_key?(result, :description)
      refute Map.has_key?(result, :total_volume)
    end

    test "handles not found error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "detail" => "Collection not found"
        }))
      end)

      assert {:error, %{detail: "Collection not found"}} =
               GetCollection.focus(%{"collection_slug" => "nonexistent"}, %{})
    end

    test "handles rate limit error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "detail" => "Request was throttled."
        }))
      end)

      assert {:error, %{detail: "Request was throttled."}} =
               GetCollection.focus(%{"collection_slug" => @collection_slug}, %{})
    end

    test "handles unauthorized error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "errors" => ["Authentication failed."]
        }))
      end)

      assert {:error, %{errors: ["Authentication failed."]}} =
               GetCollection.focus(%{"collection_slug" => @collection_slug}, %{})
    end
  end
end
