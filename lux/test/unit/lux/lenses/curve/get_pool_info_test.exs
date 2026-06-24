defmodule Lux.Lenses.Curve.GetPoolInfoTest do
  @moduledoc false
  use UnitAPICase, async: true
  alias Lux.Lenses.Curve.GetPoolInfo

  describe "focus/2" do
    test "successfully fetches pool info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.request_path == "/api/getPool/ethereum/main/0x1234"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"name" => "Test Pool", "tvl" => 50_000_000.0}
        }))
      end)

      assert {:ok, %{"name" => "Test Pool"}} = GetPoolInfo.focus(%{pool_address: "0x1234"})
    end
  end
end
