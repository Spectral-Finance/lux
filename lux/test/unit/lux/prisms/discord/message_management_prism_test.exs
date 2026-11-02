defmodule Lux.Prisms.Discord.MessageManagementPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Discord.MessageManagementPrism

  describe "handler/2 actions" do
    test "creates message via prism" do
      plug = fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/channels/111222/messages"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"id" => "msg_123", "content" => "Hello via Prism"}))
      end

      {:ok, res} =
        MessageManagementPrism.run(%{
          action: "create_message",
          payload: %{channel_id: "111222", content: "Hello via Prism", plug: plug}
        })

      assert res.action == "create_message"
      assert res.result["id"] == "msg_123"
    end

    test "bulk deletes messages via prism" do
      plug = fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/channels/111222/messages/bulk-delete"

        conn
        |> Plug.Conn.resp(204, "")
      end

      {:ok, res} =
        MessageManagementPrism.run(%{
          action: "bulk_delete",
          payload: %{channel_id: "111222", messages: ["msg1", "msg2"], plug: plug}
        })

      assert res.action == "bulk_delete"
      assert res.result.bulk_deleted == true
      assert res.result.count == 2
    end
  end
end
