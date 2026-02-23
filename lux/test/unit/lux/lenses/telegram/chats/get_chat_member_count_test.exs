defmodule Lux.Lenses.Telegram.Chats.GetChatMemberCountTest do
  @moduledoc """
  Test suite for the GetChatMemberCount lens.
  Verifies:
  - Successful member count retrieval
  - Missing required params
  - Error handling
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Chats.GetChatMemberCount

  @chat_id -1_001_234_567_890

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "retrieves chat member count" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "getChatMemberCount"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => 1543
        }))
      end)

      assert {:ok, %{member_count: 1543}} =
               GetChatMemberCount.focus(%{chat_id: @chat_id}, %{})
    end

    test "handles small group" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => 3
        }))
      end)

      assert {:ok, %{member_count: 3}} =
               GetChatMemberCount.focus(%{chat_id: @chat_id}, %{})
    end

    test "returns error when chat_id is missing" do
      assert {:error, "chat_id is required"} = GetChatMemberCount.focus(%{}, %{})
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

      assert {:error, "Bad Request: chat not found"} =
               GetChatMemberCount.focus(%{chat_id: @chat_id}, %{})
    end
  end

  describe "schema validation" do
    test "requires chat_id" do
      lens = GetChatMemberCount.view()
      assert "chat_id" in lens.schema.required
    end
  end
end
