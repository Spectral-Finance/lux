defmodule Lux.Prisms.Twitter.Automation.SendDirectMessageTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Automation.SendDirectMessage

  @agent %{name: "OutreachBot"}
  @participant_id "dm_user_789"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends a direct message" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/dm_conversations/with/#{@participant_id}/messages"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{
            "dm_conversation_id" => "conv_abc",
            "dm_event_id" => "msg_xyz"
          }
        }))
      end)

      assert {:ok, result} = SendDirectMessage.handler(%{
        participant_id: @participant_id,
        text: "Hi! Thanks for following our account."
      }, @agent)

      assert result.sent == true
      assert result.dm_conversation_id == "conv_abc"
      assert result.message_id == "msg_xyz"
      assert result.participant_id == @participant_id
    end

    test "returns error for empty message text" do
      assert {:error, message} = SendDirectMessage.handler(%{
        participant_id: @participant_id,
        text: ""
      }, @agent)
      assert message =~ "empty"
    end

    test "returns error for text over 10000 characters" do
      long_text = String.duplicate("a", 10_001)
      assert {:error, message} = SendDirectMessage.handler(%{
        participant_id: @participant_id,
        text: long_text
      }, @agent)
      assert message =~ "too long"
    end

    test "handles rate limit error" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"title" => "Too Many Requests"}))
      end)

      assert {:error, message} = SendDirectMessage.handler(%{
        participant_id: @participant_id,
        text: "Hello!"
      }, @agent)
      assert message =~ "Rate limit"
    end

    test "returns error for missing required parameters" do
      assert {:error, message} = SendDirectMessage.handler(%{participant_id: "123"}, @agent)
      assert message =~ "text"
    end

    test "handles forbidden error" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"detail" => "User has DMs disabled"}))
      end)

      assert {:error, message} = SendDirectMessage.handler(%{
        participant_id: @participant_id,
        text: "Hello!"
      }, @agent)
      assert message =~ "Failed to send DM"
    end
  end
end
