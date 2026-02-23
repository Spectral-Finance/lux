defmodule Lux.Lenses.Blur.Sales.GetCollectionSalesTest do
  @moduledoc """
  Test suite for the GetCollectionSales lens.
  Verifies:
  - Sale retrieval with price, buyer/seller data
  - Empty sales handling
  - Various price format parsing
  - Error handling
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Blur.Sales.GetCollectionSales

  @contract "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves recent sales" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "sales" => [
            %{
              "tokenId" => 1234,
              "price" => %{"amount" => "10.2"},
              "currency" => "ETH",
              "seller" => "0xseller1",
              "buyer" => "0xbuyer1",
              "createdAt" => "2024-01-15T12:00:00Z",
              "txHash" => "0xtx123"
            },
            %{
              "tokenId" => 5678,
              "price" => %{"amount" => "9.8"},
              "currency" => "ETH",
              "seller" => "0xseller2",
              "buyer" => "0xbuyer2",
              "createdAt" => "2024-01-15T11:00:00Z",
              "txHash" => "0xtx456"
            }
          ]
        }))
      end)

      assert {:ok, result} = GetCollectionSales.focus(%{"contract_address" => @contract}, %{})

      assert result.count == 2
      assert length(result.sales) == 2

      [sale1 | _] = result.sales
      assert sale1.token_id == "1234"
      assert sale1.price == 10.2
      assert sale1.price_currency == "ETH"
      assert sale1.seller == "0xseller1"
      assert sale1.buyer == "0xbuyer1"
      assert sale1.marketplace == "blur"
      assert sale1.transaction_hash == "0xtx123"
    end

    test "handles empty sales" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"sales" => []}))
      end)

      assert {:ok, result} = GetCollectionSales.focus(%{"contract_address" => @contract}, %{})
      assert result.sales == []
      assert result.count == 0
    end

    test "handles numeric price format" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "sales" => [
            %{
              "tokenId" => 42,
              "price" => 11.5,
              "currency" => "ETH",
              "seller" => "0xseller",
              "buyer" => "0xbuyer",
              "createdAt" => "2024-01-16T10:00:00Z"
            }
          ]
        }))
      end)

      assert {:ok, result} = GetCollectionSales.focus(%{"contract_address" => @contract}, %{})
      assert hd(result.sales).price == 11.5
    end

    test "handles error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Collection not found"
        }))
      end)

      assert {:error, %{message: "Collection not found"}} =
               GetCollectionSales.focus(%{"contract_address" => @contract}, %{})
    end
  end
end
