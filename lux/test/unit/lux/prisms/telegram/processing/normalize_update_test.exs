defmodule Lux.Prisms.Telegram.Processing.NormalizeUpdateTest do
  use UnitCase, async: true

  alias Lux.Prisms.Telegram.Processing.NormalizeUpdate

  describe "handler/2" do
    test "normalizes text messages with command, thread, reply, and deep link data" do
      update = %{
        "update_id" => 1001,
        "message" => %{
          "message_id" => 42,
          "message_thread_id" => 7,
          "text" => "/start onboarding",
          "chat" => %{"id" => -100, "type" => "supergroup"},
          "from" => %{"id" => 123, "username" => "alice"},
          "reply_to_message" => %{
            "message_id" => 41,
            "text" => "previous message"
          }
        }
      }

      assert {:ok, result} = NormalizeUpdate.handler(%{update: update}, nil)

      assert result.kind == "message"
      assert result.routing_key == "command:start"
      assert result.update_id == 1001
      assert result.chat_id == -100
      assert result.chat_type == "supergroup"
      assert result.message_id == 42
      assert result.thread_id == 7
      assert result.reply_to_message_id == 41
      assert result.reply_to_text == "previous message"
      assert result.from_user_id == 123
      assert result.username == "alice"
      assert result.command.command == "start"
      assert result.deep_link_payload == "onboarding"
    end

    test "normalizes callback queries into callback routing data" do
      update = %{
        update_id: 1002,
        callback_query: %{
          id: "callback-1",
          data: "approve:order-7",
          from: %{id: 456, username: "bob"},
          message: %{
            message_id: 88,
            text: "Approve order?",
            chat: %{id: 900, type: "private"}
          }
        }
      }

      assert {:ok, result} = NormalizeUpdate.handler(update, nil)

      assert result.kind == "callback_query"
      assert result.routing_key == "callback:approve"
      assert result.callback_query_id == "callback-1"
      assert result.callback_data == "approve:order-7"
      assert result.callback_action == "approve"
      assert result.callback_value == "order-7"
      assert result.chat_id == 900
      assert result.message_id == 88
      assert result.from_user_id == 456
    end

    test "normalizes edited messages and non-command text" do
      assert {:ok, result} =
               NormalizeUpdate.handler(
                 %{
                   edited_message: %{
                     message_id: 9,
                     text: "plain text",
                     chat: %{id: 1, type: "private"}
                   }
                 },
                 nil
               )

      assert result.kind == "edited_message"
      assert result.routing_key == "message:text"
      assert result.command == nil
    end

    test "rejects unsupported update shapes" do
      assert {:error, "Unsupported Telegram update"} = NormalizeUpdate.handler(%{poll: %{}}, nil)
    end
  end

  describe "schema validation" do
    test "declares input and output schemas" do
      prism = NormalizeUpdate.view()

      assert Map.has_key?(prism.input_schema.properties, :update)
      assert prism.output_schema.required == ["kind", "routing_key"]
      assert Map.has_key?(prism.output_schema.properties, :callback_data)
      assert Map.has_key?(prism.output_schema.properties, :reply_to_message_id)
    end
  end
end
