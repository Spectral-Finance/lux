defmodule Lux.Lenses.Blur.Collections.GetCollectionTest do
  @moduledoc """
  Test suite for the Blur GetCollection lens.
  Verifies:
  - Collection floor price and market stats retrieval
  - String and numeric price format parsing
  - Empty/nil field handling
  - Error response propagation
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Blur.Collections.GetCollection

  @contract "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves collection with full stats" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.request_path, @contract)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "collection" => %{
            "contractAddress" => @contract,
            "name" => "Bored Ape Yacht Club",
            "imageUrl" => "https://example.com/bayc.png",
            "totalSupply" => 10000,
            "floorAsk" => %{"amount" => "10.2", "currency" => "ETH"},
            "stats" => %{
              "numListed" => 432,
              "numOwners" => 5400,
              "volume24h" => "156.7",
              "volume7d" => "1200.5",
              "sales24h" => 14
            }
          }
        }))
      end)

      assert {:ok, result} = GetCollection.focus(%{"contract_address" => @contract}, %{})

      assert result.contract_address == @contract
      assert result.name == "Bored Ape Yacht Club"
      assert result.floor_price == 10.2
      assert result.floor_price_currency == "ETH"
      assert result.volume_24h == 156.7
      assert result.sales_24h == 14
      assert result.total_supply == 10000
    end

    test "handles numeric floor price format" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "collection" => %{
            "contractAddress" => @contract,
            "name" => "Test Collection",
            "floorAsk" => %{"amount" => 9.5, "currency" => "ETH"},
            "stats" => %{}
          }
        }))
      end)

      assert {:ok, result} = GetCollection.focus(%{"contract_address" => @contract}, %{})
      assert result.floor_price == 9.5
    end

    test "handles missing optional fields gracefully" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "collection" => %{
            "contractAddress" => @contract,
            "name" => "Minimal Collection"
          }
        }))
      end)

      assert {:ok, result} = GetCollection.focus(%{"contract_address" => @contract}, %{})
      assert result.contract_address == @contract
      assert result.name == "Minimal Collection"
      refute Map.has_key?(result, :floor_price)
      refute Map.has_key?(result, :volume_24h)
    end

    test "handles message error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Collection not found"
        }))
      end)

      assert {:error, %{message: "Collection not found"}} =
               GetCollection.focus(%{"contract_address" => @contract}, %{})
    end

    test "handles error field response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "error" => "Rate limit exceeded"
        }))
      end)

      assert {:error, %{error: "Rate limit exceeded"}} =
               GetCollection.focus(%{"contract_address" => @contract}, %{})
    end
  end
end
