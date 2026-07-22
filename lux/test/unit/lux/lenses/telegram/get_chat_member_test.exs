defmodule Lux.Lenses.Telegram.GetChatMemberTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Telegram.GetChatMember

  @chat_id "123456789"
  @user_id 98765

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully gets chat member status" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bot/getChatMember"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "status" => "member",
            "user" => %{
              "id" => @user_id,
              "is_bot" => false,
              "first_name" => "Alice",
              "username" => "alice_test"
            },
            "is_member" => true
          }
        }))
      end)

      assert {:ok, member} = GetChatMember.focus(%{
        "chat_id" => @chat_id,
        "user_id" => @user_id
      }, %{})

      assert member.status == "member"
      assert member.user.id == @user_id
      assert member.user.first_name == "Alice"
      assert member.is_member == true
    end

    test "handles error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "User not found"
        }))
      end)

      assert {:error, message} = GetChatMember.focus(%{
        "chat_id" => @chat_id,
        "user_id" => @user_id
      }, %{})

      assert message == "User not found"
    end
  end
end
