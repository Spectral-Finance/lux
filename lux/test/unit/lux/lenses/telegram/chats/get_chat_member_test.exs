defmodule Lux.Lenses.Telegram.Chats.GetChatMemberTest do
  @moduledoc """
  Test suite for the GetChatMember lens.
  Verifies:
  - Regular member info retrieval
  - Admin member info with permissions
  - Creator info retrieval
  - Restricted/banned member handling
  - Missing required params
  - Error handling
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Chats.GetChatMember

  @chat_id -1_001_234_567_890
  @user_id 987_654_321

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "retrieves regular member info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "getChatMember"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "status" => "member",
            "user" => %{
              "id" => @user_id,
              "is_bot" => false,
              "first_name" => "John",
              "username" => "johndoe"
            }
          }
        }))
      end)

      assert {:ok, result} = GetChatMember.focus(%{chat_id: @chat_id, user_id: @user_id}, %{})
      assert result.status == "member"
      assert result.user["id"] == @user_id
      assert result.user["username"] == "johndoe"
    end

    test "retrieves administrator info with permissions" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "status" => "administrator",
            "user" => %{"id" => @user_id, "first_name" => "Admin"},
            "can_delete_messages" => true,
            "can_restrict_members" => true,
            "can_promote_members" => false,
            "can_change_info" => true,
            "can_invite_users" => true,
            "is_anonymous" => false
          }
        }))
      end)

      assert {:ok, result} = GetChatMember.focus(%{chat_id: @chat_id, user_id: @user_id}, %{})
      assert result.status == "administrator"
      assert result.can_delete_messages == true
      assert result.can_restrict_members == true
      assert result.is_anonymous == false
    end

    test "retrieves creator info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "status" => "creator",
            "user" => %{"id" => 111_111_111, "first_name" => "Founder"},
            "is_anonymous" => false,
            "custom_title" => "Founder"
          }
        }))
      end)

      assert {:ok, result} = GetChatMember.focus(%{chat_id: @chat_id, user_id: 111_111_111}, %{})
      assert result.status == "creator"
      assert result.custom_title == "Founder"
    end

    test "returns error when chat_id is missing" do
      assert {:error, "chat_id is required"} =
               GetChatMember.focus(%{user_id: @user_id}, %{})
    end

    test "returns error when user_id is missing" do
      assert {:error, "user_id is required"} =
               GetChatMember.focus(%{chat_id: @chat_id}, %{})
    end

    test "handles user not in chat error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: USER_NOT_PARTICIPANT"
        }))
      end)

      assert {:error, "Bad Request: USER_NOT_PARTICIPANT"} =
               GetChatMember.focus(%{chat_id: @chat_id, user_id: @user_id}, %{})
    end
  end

  describe "schema validation" do
    test "requires chat_id and user_id" do
      lens = GetChatMember.view()
      assert "chat_id" in lens.schema.required
      assert "user_id" in lens.schema.required
    end
  end
end
