defmodule Lux.Lenses.OpenSea.Collections.GetCollectionStatsTest do
  @moduledoc """
  Test suite for the GetCollectionStats lens.
  Verifies:
  - Retrieval of full collection statistics with intervals
  - Handling of partial stats (missing intervals)
  - Proper error handling for API errors
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.OpenSea.Collections.GetCollectionStats

  @collection_slug "boredapeyachtclub"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves full collection stats with intervals" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v2/collections/#{@collection_slug}/stats"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "total" => %{
            "volume" => 987654.32,
            "sales" => 12500,
            "average_price" => 79.01,
            "market_cap" => 105000.0,
            "num_owners" => 5432,
            "floor_price" => 10.5,
            "floor_price_symbol" => "ETH",
            "total_supply" => 10000
          },
          "intervals" => [
            %{
              "interval" => "one_day",
              "volume" => 234.56,
              "volume_diff" => 45.0,
              "volume_change" => 0.24,
              "sales" => 15,
              "sales_diff" => 3,
              "average_price" => 15.6
            },
            %{
              "interval" => "seven_day",
              "volume" => 1234.78,
              "sales" => 84,
              "average_price" => 14.7
            }
          ]
        }))
      end)

      assert {:ok, result} = GetCollectionStats.focus(%{"collection_slug" => @collection_slug}, %{})

      assert result.floor_price == 10.5
      assert result.floor_price_currency == "ETH"
      assert result.total_supply == 10000
      assert result.num_owners == 5432
      assert result.market_cap == 105000.0
      assert result.total_volume == 987654.32
      assert result.total_sales == 12500

      assert length(result.intervals) == 2
      [day1 | _] = result.intervals
      assert day1.interval == "one_day"
      assert day1.volume == 234.56
      assert day1.sales == 15
      assert day1.average_price == 15.6
    end

    test "handles empty intervals gracefully" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "total" => %{
            "volume" => 100.0,
            "floor_price" => 0.5,
            "floor_price_symbol" => "ETH",
            "total_supply" => 5000,
            "num_owners" => 2000
          },
          "intervals" => []
        }))
      end)

      assert {:ok, result} = GetCollectionStats.focus(%{"collection_slug" => @collection_slug}, %{})

      assert result.floor_price == 0.5
      assert result.total_supply == 5000
      assert result.intervals == []
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
               GetCollectionStats.focus(%{"collection_slug" => "nonexistent"}, %{})
    end

    test "handles authentication error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "errors" => ["Unauthorized: Invalid API key."]
        }))
      end)

      assert {:error, %{errors: ["Unauthorized: Invalid API key."]}} =
               GetCollectionStats.focus(%{"collection_slug" => @collection_slug}, %{})
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
               GetCollectionStats.focus(%{"collection_slug" => @collection_slug}, %{})
    end
  end
end
