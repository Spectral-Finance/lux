defmodule Lux.Lenses.X2Y2.Collections.GetCollectionTest do
  @moduledoc """
  Test suite for the X2Y2 GetCollection lens.
  Verifies:
  - Collection stat retrieval with wei price conversion
  - Partial data handling
  - Error propagation
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.X2Y2.Collections.GetCollection

  @contract "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves collection with wei price conversion" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ @contract

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "contract" => @contract,
            "name" => "Bored Ape Yacht Club",
            "image" => "https://example.com/image.png",
            "floor_price" => "10100000000000000000",
            "volume_24h" => "145300000000000000000",
            "volume_total" => "523400000000000000000000",
            "owners" => 5430,
            "total" => 10000,
            "listed" => 420,
            "sales_24h" => 12,
            "royalty" => 250
          }
        }))
      end)

      assert {:ok, result} = GetCollection.focus(%{"contract" => @contract}, %{})

      assert result.contract == @contract
      assert result.name == "Bored Ape Yacht Club"
      assert_in_delta result.floor_price, 10.1, 0.01
      assert_in_delta result.volume_24h, 145.3, 0.1
      assert result.num_owners == 5430
      assert result.total_supply == 10000
      assert result.listed_count == 420
      assert result.royalty_bps == 250
      assert result.floor_price_currency == "ETH"
    end

    test "handles missing optional fields" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "contract" => @contract,
            "name" => "Minimal Collection",
            "floor_price" => "500000000000000000",
            "owners" => 100,
            "total" => 1000
          }
        }))
      end)

      assert {:ok, result} = GetCollection.focus(%{"contract" => @contract}, %{})

      assert result.name == "Minimal Collection"
      assert_in_delta result.floor_price, 0.5, 0.001
      refute Map.has_key?(result, :volume_24h)
      refute Map.has_key?(result, :royalty_bps)
    end

    test "handles not found error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Contract not found"
        }))
      end)

      assert {:error, %{message: "Contract not found"}} =
               GetCollection.focus(%{"contract" => @contract}, %{})
    end

    test "handles unauthorized error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "errors" => ["Unauthorized: API key invalid"]
        }))
      end)

      assert {:error, %{errors: _}} =
               GetCollection.focus(%{"contract" => @contract}, %{})
    end
  end
end
