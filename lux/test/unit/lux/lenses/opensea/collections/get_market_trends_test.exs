defmodule Lux.Lenses.OpenSea.Collections.GetMarketTrendsTest do
  @moduledoc """
  Test suite for the GetMarketTrends lens.
  Verifies:
  - Retrieval of trending collections with volume data
  - Pagination cursor support
  - Error handling for API errors
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.OpenSea.Collections.GetMarketTrends

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves trending collections with stats" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v2/collections"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "collections" => [
            %{
              "collection" => "boredapeyachtclub",
              "name" => "Bored Ape Yacht Club",
              "image_url" => "https://example.com/image.png",
              "stats" => %{
                "floor_price" => 10.5,
                "floor_price_symbol" => "ETH",
                "one_day_volume" => 234.56,
                "one_day_sales" => 15,
                "one_day_average_price" => 15.6,
                "seven_day_volume" => 1234.78,
                "seven_day_sales" => 84,
                "thirty_day_volume" => 5678.9,
                "total_volume" => 987654.32,
                "total_sales" => 12500,
                "num_owners" => 5432,
                "total_supply" => 10000,
                "market_cap" => 105000.0
              }
            },
            %{
              "collection" => "cryptopunks",
              "name" => "CryptoPunks",
              "stats" => %{
                "floor_price" => 45.0,
                "floor_price_symbol" => "ETH",
                "one_day_volume" => 180.0,
                "one_day_sales" => 4,
                "total_supply" => 10000,
                "num_owners" => 3512
              }
            }
          ],
          "next" => "trend_cursor_123"
        }))
      end)

      assert {:ok, result} = GetMarketTrends.focus(%{"sort_by" => "one_day_volume"}, %{})

      assert result.count == 2
      assert result.next_cursor == "trend_cursor_123"

      [top | _] = result.collections
      assert top.collection == "boredapeyachtclub"
      assert top.name == "Bored Ape Yacht Club"
      assert top.floor_price == 10.5
      assert top.floor_price_currency == "ETH"
      assert top.one_day_volume == 234.56
      assert top.total_volume == 987654.32
      assert top.num_owners == 5432
    end

    test "handles empty collections list" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "collections" => [],
          "next" => nil
        }))
      end)

      assert {:ok, result} = GetMarketTrends.focus(%{}, %{})
      assert result.collections == []
      assert result.count == 0
      refute Map.has_key?(result, :next_cursor)
    end

    test "handles authentication error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "errors" => ["Authentication credentials were not provided."]
        }))
      end)

      assert {:error, %{errors: _}} = GetMarketTrends.focus(%{}, %{})
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
               GetMarketTrends.focus(%{}, %{})
    end
  end
end
