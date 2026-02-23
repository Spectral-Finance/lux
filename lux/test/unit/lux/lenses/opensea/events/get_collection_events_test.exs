defmodule Lux.Lenses.OpenSea.Events.GetCollectionEventsTest do
  @moduledoc """
  Test suite for the OpenSea GetCollectionEvents lens.
  Verifies:
  - Sale event retrieval with price and buyer/seller data
  - Transfer event handling
  - Listing event handling
  - Empty events handling
  - Pagination cursor propagation
  - Error response handling
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.OpenSea.Events.GetCollectionEvents

  @collection_slug "boredapeyachtclub"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves sale events" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.request_path, @collection_slug)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "asset_events" => [
            %{
              "event_type" => "sale",
              "chain" => "ethereum",
              "transaction" => "0xtx123",
              "event_timestamp" => "2024-01-15T12:00:00.000Z",
              "sale_price" => "15500000000000000000",
              "payment" => %{
                "symbol" => "ETH",
                "decimals" => 18
              },
              "payment_usd" => "37200.00",
              "seller" => "0xseller123",
              "buyer" => "0xbuyer456",
              "quantity" => 1,
              "nft" => %{
                "identifier" => "1234",
                "collection" => @collection_slug,
                "contract" => "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
                "name" => "Bored Ape #1234",
                "image_url" => "https://example.com/ape1234.png"
              }
            }
          ],
          "next" => "cursor_abc123"
        }))
      end)

      assert {:ok, result} =
               GetCollectionEvents.focus(%{"collection_slug" => @collection_slug}, %{})

      assert length(result.events) == 1
      assert result.next_cursor == "cursor_abc123"

      [event] = result.events
      assert event.event_type == "sale"
      assert event.chain == "ethereum"
      assert event.price == 15.5
      assert event.price_currency == "ETH"
      assert event.seller == "0xseller123"
      assert event.buyer == "0xbuyer456"
      assert event.nft.identifier == "1234"
      assert event.nft.name == "Bored Ape #1234"
    end

    test "successfully retrieves transfer events" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "asset_events" => [
            %{
              "event_type" => "transfer",
              "chain" => "ethereum",
              "transaction" => "0xtransfer789",
              "event_timestamp" => "2024-01-16T08:00:00.000Z",
              "from_address" => "0xfrom111",
              "to_address" => "0xto222",
              "quantity" => 1,
              "nft" => %{
                "identifier" => "5678",
                "collection" => @collection_slug,
                "contract" => "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"
              }
            }
          ],
          "next" => nil
        }))
      end)

      assert {:ok, result} =
               GetCollectionEvents.focus(
                 %{"collection_slug" => @collection_slug, "event_type" => "transfer"},
                 %{}
               )

      [event] = result.events
      assert event.event_type == "transfer"
      assert event.from_address == "0xfrom111"
      assert event.to_address == "0xto222"
    end

    test "handles empty events list" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "asset_events" => [],
          "next" => nil
        }))
      end)

      assert {:ok, result} =
               GetCollectionEvents.focus(%{"collection_slug" => @collection_slug}, %{})

      assert result.events == []
      assert result.next_cursor == nil
    end

    test "handles listing events" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "asset_events" => [
            %{
              "event_type" => "listing",
              "chain" => "ethereum",
              "starting_price" => "10000000000000000000",
              "payment" => %{"symbol" => "ETH", "decimals" => 18},
              "maker" => "0xmaker999",
              "expiration_date" => "2024-02-01T00:00:00.000Z",
              "nft" => %{
                "identifier" => "42",
                "collection" => @collection_slug,
                "contract" => "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"
              }
            }
          ],
          "next" => nil
        }))
      end)

      assert {:ok, result} =
               GetCollectionEvents.focus(
                 %{"collection_slug" => @collection_slug, "event_type" => "listing"},
                 %{}
               )

      [event] = result.events
      assert event.event_type == "listing"
      assert event.price == 10.0
      assert event.maker == "0xmaker999"
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
               GetCollectionEvents.focus(%{"collection_slug" => "nonexistent"}, %{})
    end
  end
end
