defmodule Lux.Integrations.CurveFinance.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.CurveFinance.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "Curve API helpers" do
    test "fetches all pools for a chain" do
      Req.Test.expect(CurveFinanceClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v1/getPools/all/ethereum"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "data" => %{
              "poolData" => [
                %{"name" => "3pool", "address" => "0xpool"}
              ]
            }
          })
        )
      end)

      assert {:ok, %{"data" => %{"poolData" => [%{"name" => "3pool"}]}}} =
               Client.pools(:ethereum, plug: {Req.Test, CurveFinanceClientMock})
    end

    test "fetches registry pools with string ids" do
      Req.Test.expect(CurveFinanceClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v1/getPools/base/factory-stable-ng"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"poolData" => []}}))
      end)

      assert {:ok, %{"data" => %{"poolData" => []}}} =
               Client.registry_pools("base", "factory-stable-ng",
                 plug: {Req.Test, CurveFinanceClientMock}
               )
    end

    test "fetches gauges and normalizes errors" do
      Req.Test.expect(CurveFinanceClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v1/getAllGauges"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"error" => "unavailable"}))
      end)

      assert {:error, {400, "unavailable"}} =
               Client.gauges(plug: {Req.Test, CurveFinanceClientMock})
    end
  end
end
