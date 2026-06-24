defmodule Lux.Lenses.PancakeSwap.Pools.GetPoolsTest do
  @moduledoc false
  use UnitAPICase, async: true
  alias Lux.Lenses.PancakeSwap.Pools.GetPools

  describe "focus/2" do
    test "successfully fetches PancakeSwap pools" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v2/pools"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"pools" => [%{"id" => "0x1", "name" => "CAKE-BNB"}]}
        }))
      end)

      assert {:ok, %{"pools" => _}} = GetPools.focus(%{})
    end
  end
end
