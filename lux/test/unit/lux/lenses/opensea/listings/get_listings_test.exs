defmodule Lux.Lenses.OpenSea.Listings.GetListingsTest do
  @moduledoc """
  Test suite for the GetListings lens.
  Verifies:
  - Retrieval of active listings with price data
  - Pagination cursor handling
  - Error propagation
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.OpenSea.Listings.GetListings

  @collection_slug "boredapeyachtclub"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves listings with price data" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v2/listings/collection/#{@collection_slug}/all"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "listings" => [
            %{
              "order_hash" => "0xabc123",
              "order_type" => "basic",
              "price" => %{
                "current" => %{
                  "value" => "10500000000000000000",
                  "decimals" => 18,
                  "currency" => "ETH"
                }
              },
              "protocol_data" => %{
                "parameters" => %{
                  "offerer" => "0xseller123",
                  "endTime" => "1893456000",
                  "offer" => [%{"identifierOrCriteria" => "1234", "token" => "0xcontract"}],
                  "consideration" => [%{"token" => "0x0"}]
                }
              },
              "created_date" => "2024-01-15T12:00:00.000Z"
            }
          ],
          "next" => "cursor_xyz"
        }))
      end)

      assert {:ok, result} = GetListings.focus(%{"collection_slug" => @collection_slug}, %{})

      assert length(result.listings) == 1
      assert result.next_cursor == "cursor_xyz"

      [listing | _] = result.listings
      assert listing.order_hash == "0xabc123"
      assert listing.order_type == "basic"
      assert listing.seller == "0xseller123"
      assert listing.price_currency == "ETH"
      assert listing.nft.identifier == "1234"
    end

    test "handles empty listings" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "listings" => [],
          "next" => nil
        }))
      end)

      assert {:ok, result} = GetListings.focus(%{"collection_slug" => @collection_slug}, %{})
      assert result.listings == []
      refute Map.has_key?(result, :next_cursor)
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
               GetListings.focus(%{"collection_slug" => "nonexistent"}, %{})
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
               GetListings.focus(%{"collection_slug" => @collection_slug}, %{})
    end
  end
end
