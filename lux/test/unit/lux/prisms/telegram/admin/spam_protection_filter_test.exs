defmodule Lux.Prisms.Telegram.Admin.SpamProtectionFilterTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Admin.SpamProtectionFilter

  @chat_id "123456789"
  @user_id 987654
  @message_id 555
  @agent_ctx %{name: "SpamGuardAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "evaluates clean message as clean" do
      assert {:ok, result} = SpamProtectionFilter.handler(%{
        chat_id: @chat_id,
        text: "Hello everyone, welcome to the group!"
      }, @agent_ctx)

      assert result.is_spam == false
      assert result.matched_keywords == []
      assert result.action_taken == "clean"
    end

    test "detects default spam keywords and flags message" do
      assert {:ok, result} = SpamProtectionFilter.handler(%{
        chat_id: @chat_id,
        text: "Join our casino now and make money fast!"
      }, @agent_ctx)

      assert result.is_spam == true
      assert "casino" in result.matched_keywords
      assert "make money fast" in result.matched_keywords
      assert result.action_taken == "flagged"
    end

    test "supports custom spam keywords list" do
      assert {:ok, result} = SpamProtectionFilter.handler(%{
        chat_id: @chat_id,
        text: "Click here to claim free airdrop token",
        spam_keywords: ["airdrop token", "claim free"]
      }, @agent_ctx)

      assert result.is_spam == true
      assert result.matched_keywords == ["airdrop token", "claim free"]
    end

    test "executes delete_and_mute action when spam is detected and message/user IDs are present" do
      # Expect deleteMessage call
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/deleteMessage")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      # Expect restrictChatMember call
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/restrictChatMember")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["user_id"] == @user_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, result} = SpamProtectionFilter.handler(%{
        chat_id: @chat_id,
        message_id: @message_id,
        user_id: @user_id,
        text: "Win big at our online casino!",
        action: "delete_and_mute"
      }, @agent_ctx)

      assert result.is_spam == true
      assert result.action_taken == "deleted_and_muted"
    end

    test "returns error on missing required params" do
      assert {:error, "Missing or invalid chat_id"} = SpamProtectionFilter.handler(%{text: "some text"}, @agent_ctx)
      assert {:error, "Missing or invalid text"} = SpamProtectionFilter.handler(%{chat_id: @chat_id}, @agent_ctx)
    end
  end
end
