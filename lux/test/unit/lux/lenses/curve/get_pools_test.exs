defmodule Lux.Lenses.Curve.GetPoolsTest do
  @moduledoc false
  use UnitAPICase, async: true
  alias Lux.Lenses.Curve.GetPools

  describe "focus/2" do
    test "successfully fetches Curve pools" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/getPools/ethereum/main"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "poolData" => [
              %{"id" => "0x1", "name" => "3pool", "tvl" => 100_000_000.0}
            ]
          }
        }))
      end)

      assert {:ok, %{pools: [%{"id" => "0x1"}]}} = GetPools.focus(%{})
    end

    test "handles API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"error" => "Bad request"}))
      end)

      assert {:error, "Bad request"} = GetPools.focus(%{})
    end
  end
end
