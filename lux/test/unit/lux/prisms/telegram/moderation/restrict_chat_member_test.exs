defmodule Lux.Prisms.Telegram.Moderation.RestrictChatMemberTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Moderation.RestrictChatMember

  @chat_id "123456789"
  @user_id 987654
  @agent_ctx %{name: "Agent"}
  @permissions %{
    "can_send_messages" => false,
    "can_send_audios" => false
  }

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully restricts a user" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/restrictChatMember")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["user_id"] == @user_id
        assert decoded["permissions"] == @permissions

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, response} = RestrictChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id,
        permissions: @permissions,
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
          "description" => "Method restrictChatMember failed"
        }))
      end)

      assert {:error, message} = RestrictChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id,
        permissions: @permissions,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert String.contains?(message, "Method restrictChatMember failed")
    end

    test "explicitly passes false values for independent permissions" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["user_id"] == @user_id
        assert decoded["use_independent_chat_permissions"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, response} = RestrictChatMember.handler(%{
        chat_id: @chat_id,
        user_id: @user_id,
        permissions: @permissions,
        use_independent_chat_permissions: false,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.success == true
    end
  end
end
