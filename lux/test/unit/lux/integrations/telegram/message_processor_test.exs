defmodule Lux.Integrations.Telegram.MessageProcessorTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Telegram.MessageProcessor

  describe "classify_update/1" do
    test "classifies common update types" do
      assert MessageProcessor.classify_update(%{"message" => %{"text" => "hello"}}) == :text_message
      assert MessageProcessor.classify_update(%{"message" => %{"photo" => []}}) == :photo_message
      assert MessageProcessor.classify_update(%{"callback_query" => %{}}) == :callback_query
      assert MessageProcessor.classify_update(%{"inline_query" => %{}}) == :inline_query
      assert MessageProcessor.classify_update(%{"poll" => %{}}) == :unknown
    end
  end

  describe "parse_command/2" do
    test "parses commands with args" do
      assert MessageProcessor.parse_command("/deploy prod now") == {
               :ok,
               %{command: "deploy", bot: nil, args: ["prod", "now"], raw_args: "prod now"}
             }
    end

    test "honors bot mentions in group commands" do
      assert MessageProcessor.parse_command("/start@LuxBot payload", %{bot_username: "luxbot"}) == {
               :ok,
               %{command: "start", bot: "LuxBot", args: ["payload"], raw_args: "payload"}
             }

      assert MessageProcessor.parse_command("/start@OtherBot payload", %{bot_username: "luxbot"}) == :ignore
    end
  end

  describe "deep_link_payload/2" do
    test "extracts start payloads" do
      assert MessageProcessor.deep_link_payload("/start invite_123") == {:ok, "invite_123"}
      assert MessageProcessor.deep_link_payload("/help invite_123") == :ignore
    end
  end

  describe "decode_callback_data/1" do
    test "splits action and payload" do
      assert MessageProcessor.decode_callback_data("approve:ticket-123") == %{
               action: "approve",
               payload: "ticket-123"
             }

      assert MessageProcessor.decode_callback_data("refresh") == %{action: "refresh", payload: nil}
    end
  end

  describe "thread_context/1" do
    test "extracts reply and thread fields" do
      message = %{
        "chat" => %{"id" => 123},
        "message_id" => 10,
        "message_thread_id" => 5,
        "reply_to_message" => %{
          "message_id" => 9,
          "from" => %{"id" => 42}
        }
      }

      assert MessageProcessor.thread_context(message) == %{
               chat_id: 123,
               message_id: 10,
               message_thread_id: 5,
               reply_to_message_id: 9,
               reply_to_user_id: 42
             }
    end
  end

  describe "format escaping" do
    test "escapes markdown v2 and html text" do
      assert MessageProcessor.escape_markdown_v2("hello_world!") == "hello\\_world\\!"
      assert MessageProcessor.escape_html("<b>Tom & Co</b>") == "&lt;b&gt;Tom &amp; Co&lt;/b&gt;"
    end
  end
end
