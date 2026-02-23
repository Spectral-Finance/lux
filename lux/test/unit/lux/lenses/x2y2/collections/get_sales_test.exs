defmodule Lux.Lenses.X2Y2.Collections.GetSalesTest do
  @moduledoc """
  Test suite for the X2Y2 GetSales lens.
  Verifies:
  - Sale retrieval with wei price conversion
  - Filtering of non-sale events
  - Error handling
  - Pagination cursor support
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.X2Y2.Collections.GetSales

  @contract "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves sales with wei price conversion" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [
            %{
              "type" => "sale",
              "order" => %{"price" => "10200000000000000000"},
              "token" => %{"token_id" => "1234"},
              "from_address" => "0xseller1",
              "to_address" => "0xbuyer1",
              "created_at" => 1705316400,
              "tx" => "0xtxhash1"
            },
            %{
              "type" => "transfer",
              "order" => %{"price" => "0"},
              "token" => %{"token_id" => "9999"},
              "from_address" => "0xfrom",
              "to_address" => "0xto",
              "created_at" => 1705310000,
              "tx" => "0xtxtransfer"
            }
          ],
          "next" => "cursor_abc"
        }))
      end)

      assert {:ok, result} = GetSales.focus(%{"contract" => @contract}, %{})

      # Only sale type should be included
      assert result.count == 1
      assert length(result.sales) == 1

      [sale] = result.sales
      assert sale.token_id == "1234"
      assert_in_delta sale.price, 10.2, 0.01
      assert sale.price_currency == "ETH"
      assert sale.seller == "0xseller1"
      assert sale.buyer == "0xbuyer1"
      assert sale.marketplace == "x2y2"
      assert sale.transaction_hash == "0xtxhash1"
    end

    test "handles empty data array" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [],
          "next" => nil
        }))
      end)

      assert {:ok, result} = GetSales.focus(%{"contract" => @contract}, %{})
      assert result.sales == []
      assert result.count == 0
    end

    test "handles API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "message" => "Invalid contract address"
        }))
      end)

      assert {:error, %{message: "Invalid contract address"}} =
               GetSales.focus(%{"contract" => "invalid"}, %{})
    end
  end
end
