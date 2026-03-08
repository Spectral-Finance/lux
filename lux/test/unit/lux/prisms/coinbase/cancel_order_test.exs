defmodule Lux.Prisms.Coinbase.CancelOrderTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Coinbase.CancelOrder
  alias Lux.Integrations.Coinbase.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "cancels orders successfully" do
      Req.Test.stub(Client, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["order_ids"] == ["order-1", "order-2"]

        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"results" => [
          %{"order_id" => "order-1", "success" => true},
          %{"order_id" => "order-2", "success" => true}
        ]}))
      end)

      assert {:ok, result} = CancelOrder.handler(%{order_ids: ["order-1", "order-2"]}, %{name: "Test"})
      assert result.success == true
      assert length(result.results) == 2
    end

    test "handles partial failure" do
      Req.Test.stub(Client, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"results" => [
          %{"order_id" => "order-1", "success" => true},
          %{"order_id" => "order-2", "success" => false}
        ]}))
      end)

      assert {:ok, result} = CancelOrder.handler(%{order_ids: ["order-1", "order-2"]}, %{name: "Test"})
      assert result.success == false
    end

    test "handles empty order_ids" do
      assert {:error, "No order IDs provided"} = CancelOrder.handler(%{order_ids: []}, %{name: "Test"})
    end
  end
end
