defmodule Lux.Prisms.Telegram.Moderation.PromoteChatMemberTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Moderation.PromoteChatMember

  @chat_id "123456789"
  @user_id 987654
  @agent_ctx %{name: "Agent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully promotes a user" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/promoteChatMember")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["user_id"] == @user_id
        assert decoded["can_change_info"] == true
        assert decoded["can_pin_messages"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, response} = PromoteChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id,
        can_change_info: true,
        can_pin_messages: true,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.success == true
    end

    test "handles error response" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Not enough rights to promote member"
        }))
      end)

      assert {:error, message} = PromoteChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert String.contains?(message, "Not enough rights to promote member")
    end

    test "explicitly passes false values for revoking permissions" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["user_id"] == @user_id
        assert decoded["can_post_messages"] == false
        assert decoded["can_edit_messages"] == false
        assert decoded["can_delete_messages"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, response} = PromoteChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id,
        can_post_messages: false,
        can_edit_messages: false,
        can_delete_messages: false,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.success == true
    end
  end
end
