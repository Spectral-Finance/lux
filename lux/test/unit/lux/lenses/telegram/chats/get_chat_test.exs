defmodule Lux.Lenses.Telegram.Chats.GetChatTest do
  @moduledoc """
  Test suite for the GetChat lens.
  Verifies:
  - Group chat info retrieval
  - Private chat info retrieval
  - Channel info retrieval
  - Missing required params
  - Error handling
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Chats.GetChat

  @chat_id -1_001_234_567_890

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "retrieves supergroup chat info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "getChat"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "id" => @chat_id,
            "type" => "supergroup",
            "title" => "My Group",
            "username" => "mygroup",
            "description" => "A great group",
            "invite_link" => "https://t.me/mygroup",
            "member_count" => 150
          }
        }))
      end)

      assert {:ok, result} = GetChat.focus(%{chat_id: @chat_id}, %{})
      assert result.id == @chat_id
      assert result.type == "supergroup"
      assert result.title == "My Group"
      assert result.username == "mygroup"
      assert result.member_count == 150
    end

    test "retrieves private chat info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "id" => 123_456_789,
            "type" => "private",
            "first_name" => "John",
            "last_name" => "Doe",
            "username" => "johndoe"
          }
        }))
      end)

      assert {:ok, result} = GetChat.focus(%{chat_id: 123_456_789}, %{})
      assert result.type == "private"
      assert result.first_name == "John"
    end

    test "returns error when chat_id is missing" do
      assert {:error, "chat_id is required"} = GetChat.focus(%{}, %{})
    end

    test "handles chat not found error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: chat not found"
        }))
      end)

      assert {:error, "Bad Request: chat not found"} = GetChat.focus(%{chat_id: @chat_id}, %{})
    end

    test "supports string chat_id" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "id" => -1_001_000_000_001,
            "type" => "channel",
            "title" => "My Channel",
            "username" => "mychannel"
          }
        }))
      end)

      assert {:ok, result} = GetChat.focus(%{chat_id: "@mychannel"}, %{})
      assert result.type == "channel"
    end
  end

  describe "schema validation" do
    test "requires chat_id" do
      lens = GetChat.view()
      assert "chat_id" in lens.schema.required
    end
  end
end
