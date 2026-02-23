defmodule Lux.Lenses.Telegram.Chats.GetChatAdministratorsTest do
  @moduledoc """
  Test suite for the GetChatAdministrators lens.
  Verifies:
  - Retrieval of admin list with creator and admins
  - Handling of anonymous admins
  - Missing required params
  - Error handling
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Chats.GetChatAdministrators

  @chat_id -1_001_234_567_890

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "retrieves list of administrators" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "getChatAdministrators"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "status" => "creator",
              "user" => %{"id" => 111_111_111, "first_name" => "Alice"},
              "is_anonymous" => false,
              "custom_title" => "Founder"
            },
            %{
              "status" => "administrator",
              "user" => %{"id" => 222_222_222, "first_name" => "Bob"},
              "can_delete_messages" => true,
              "can_restrict_members" => false,
              "is_anonymous" => false
            }
          ]
        }))
      end)

      assert {:ok, admins} = GetChatAdministrators.focus(%{chat_id: @chat_id}, %{})
      assert length(admins) == 2

      creator = Enum.find(admins, &(&1.status == "creator"))
      assert creator.user["first_name"] == "Alice"
      assert creator.custom_title == "Founder"

      admin = Enum.find(admins, &(&1.status == "administrator"))
      assert admin.user["first_name"] == "Bob"
      assert admin.can_delete_messages == true
    end

    test "handles anonymous administrator" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "status" => "administrator",
              "user" => %{"id" => 333_333_333, "first_name" => "Anon"},
              "is_anonymous" => true,
              "custom_title" => "Moderator"
            }
          ]
        }))
      end)

      assert {:ok, [admin]} = GetChatAdministrators.focus(%{chat_id: @chat_id}, %{})
      assert admin.is_anonymous == true
      assert admin.custom_title == "Moderator"
    end

    test "returns error when chat_id is missing" do
      assert {:error, "chat_id is required"} = GetChatAdministrators.focus(%{}, %{})
    end

    test "handles bot not in chat error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: there are no administrators in the private chat"
        }))
      end)

      assert {:error, "Bad Request: there are no administrators in the private chat"} =
               GetChatAdministrators.focus(%{chat_id: @chat_id}, %{})
    end
  end

  describe "schema validation" do
    test "requires chat_id" do
      lens = GetChatAdministrators.view()
      assert "chat_id" in lens.schema.required
    end
  end
end
