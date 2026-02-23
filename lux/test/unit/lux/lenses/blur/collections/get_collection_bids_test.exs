defmodule Lux.Lenses.Blur.Collections.GetCollectionBidsTest do
  @moduledoc """
  Test suite for the GetCollectionBids lens.
  Verifies:
  - Retrieval of bid depth with price levels
  - Best bid extraction
  - Total bid value calculation
  - Error handling
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Blur.Collections.GetCollectionBids

  @contract "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves bid depth with multiple price levels" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ @contract

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "contractAddress" => @contract,
          "priceLevels" => [
            %{
              "price" => "9.8",
              "bidCount" => 12,
              "numberBids" => 12
            },
            %{
              "price" => "9.5",
              "bidCount" => 25,
              "numberBids" => 25
            },
            %{
              "price" => "9.0",
              "bidCount" => 40,
              "numberBids" => 40
            }
          ]
        }))
      end)

      assert {:ok, result} = GetCollectionBids.focus(%{"contract_address" => @contract}, %{})

      assert result.contract_address == @contract
      assert length(result.bids) == 3
      assert result.best_bid == 9.8
      assert result.best_bid_currency == "ETH"
      assert result.total_bid_value > 0

      [top_bid | _] = result.bids
      assert top_bid.price == 9.8
      assert top_bid.bid_count == 12
    end

    test "handles empty bid book" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "contractAddress" => @contract,
          "priceLevels" => []
        }))
      end)

      assert {:ok, result} = GetCollectionBids.focus(%{"contract_address" => @contract}, %{})
      assert result.bids == []
      refute Map.has_key?(result, :best_bid)
    end

    test "handles not found error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Collection not found"
        }))
      end)

      assert {:error, %{message: "Collection not found"}} =
               GetCollectionBids.focus(%{"contract_address" => @contract}, %{})
    end

    test "handles API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{
          "error" => "Internal server error"
        }))
      end)

      assert {:error, %{error: "Internal server error"}} =
               GetCollectionBids.focus(%{"contract_address" => @contract}, %{})
    end
  end
end
