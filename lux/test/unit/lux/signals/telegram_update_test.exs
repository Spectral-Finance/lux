defmodule Lux.Signals.TelegramUpdateTest do
  use UnitCase, async: true

  alias Lux.Signals.TelegramUpdate
  alias Lux.Telegram.Types.{Chat, Message, Update, User}

  describe "new/1 constructor" do
    test "creates signal with raw atom key map" do
      raw = %{
        update_id: 123_456,
        message: %{
          message_id: 1,
          date: 1_700_000_000,
          chat: %{id: 999, type: "private"},
          text: "hello world"
        }
      }

      assert {:ok, %Lux.Signal{} = signal} = TelegramUpdate.new(raw)
      assert signal.schema_id == Lux.Schemas.TelegramUpdateSchema
      assert signal.payload.update_id == 123_456
      assert is_binary(signal.id)
      assert %DateTime{} = signal.timestamp
    end

    test "creates signal with raw string key map" do
      raw = %{
        "update_id" => 789_012,
        "message" => %{
          "message_id" => 2,
          "date" => 1_700_000_000,
          "chat" => %{"id" => 888, "type" => "group"},
          "text" => "string keys test"
        }
      }

      assert {:ok, %Lux.Signal{} = signal} = TelegramUpdate.new(raw)
      assert signal.schema_id == Lux.Schemas.TelegramUpdateSchema
      assert signal.payload["update_id"] == 789_012
    end

    test "creates signal with structured signal map preserving metadata and fields" do
      attrs = %{
        id: "custom-signal-id-123",
        sender: "telegram-bot-service",
        recipient: "agent-worker",
        topic: "telegram/updates",
        metadata: %{source: "webhook", ip: "1.2.3.4"},
        payload: %{
          update_id: 555_666,
          message: %{
            message_id: 10,
            text: "structured signal"
          }
        }
      }

      assert {:ok, %Lux.Signal{} = signal} = TelegramUpdate.new(attrs)
      assert signal.id == "custom-signal-id-123"
      assert signal.sender == "telegram-bot-service"
      assert signal.recipient == "agent-worker"
      assert signal.topic == "telegram/updates"
      assert signal.metadata == %{source: "webhook", ip: "1.2.3.4"}
      assert signal.payload.update_id == 555_666
    end

    test "creates signal with structured signal map using string keys" do
      attrs = %{
        "id" => "custom-signal-id-456",
        "sender" => "bot-sender",
        "recipient" => "bot-recipient",
        "topic" => "telegram/channel",
        "metadata" => %{"env" => "test"},
        "payload" => %{
          "update_id" => 333_444
        }
      }

      assert {:ok, %Lux.Signal{} = signal} = TelegramUpdate.new(attrs)
      assert signal.id == "custom-signal-id-456"
      assert signal.sender == "bot-sender"
      assert signal.recipient == "bot-recipient"
      assert signal.topic == "telegram/channel"
      assert signal.metadata == %{"env" => "test"}
      assert signal.payload["update_id"] == 333_444
    end

    test "creates signal from %Lux.Telegram.Types.Update{} struct" do
      update = %Update{
        update_id: 999_888,
        message: %Message{
          message_id: 42,
          date: 1_700_000_000,
          text: "from struct",
          from: %User{id: 101, first_name: "Alice", is_bot: false},
          chat: %Chat{id: 202, type: "private"}
        }
      }

      assert {:ok, %Lux.Signal{} = signal} = TelegramUpdate.new(update)
      assert signal.schema_id == Lux.Schemas.TelegramUpdateSchema
      assert signal.payload.update_id == 999_888
      assert signal.payload.message.text == "from struct"
      assert signal.payload.message.chat.id == 202
      assert signal.payload.message.from.first_name == "Alice"
    end

    test "fails validation when update_id is missing" do
      invalid_raw = %{
        message: %{
          text: "missing update_id"
        }
      }

      assert {:error, _errors} = TelegramUpdate.new(invalid_raw)
    end

    test "fails validation when update_id has invalid type" do
      invalid_type = %{
        update_id: "not-an-integer",
        message: %{text: "bad type"}
      }

      assert {:error, _errors} = TelegramUpdate.new(invalid_type)
    end

    test "fails when input is not a map" do
      assert {:error, :invalid_update} = TelegramUpdate.new("not-a-map")
      assert {:error, :invalid_update} = TelegramUpdate.new(12345)
      assert {:error, :invalid_update} = TelegramUpdate.new(nil)
    end
  end

  describe "application-layer helpers" do
    test "to_struct/1 converts signal and maps to %Lux.Telegram.Types.Update{}" do
      raw = %{
        "update_id" => 123,
        "message" => %{
          "message_id" => 1,
          "text" => "hello",
          "chat" => %{"id" => 456, "type" => "private"}
        }
      }

      {:ok, signal} = TelegramUpdate.new(raw)

      struct_from_signal = TelegramUpdate.to_struct(signal)
      assert %Update{update_id: 123} = struct_from_signal
      assert %Message{text: "hello", chat: %Chat{id: 456}} = struct_from_signal.message

      struct_from_map = TelegramUpdate.to_struct(raw)
      assert %Update{update_id: 123} = struct_from_map

      assert TelegramUpdate.to_struct(struct_from_signal) == struct_from_signal
      assert is_nil(TelegramUpdate.to_struct(nil))
    end

    test "to_atom_keys/1 converts map or signal payload keys recursively" do
      string_map = %{
        "update_id" => 123,
        "message" => %{
          "text" => "hello",
          "chat" => %{"id" => 456}
        }
      }

      {:ok, signal} = TelegramUpdate.new(string_map)

      atom_map = TelegramUpdate.to_atom_keys(signal)
      assert atom_map == %{
        update_id: 123,
        message: %{
          text: "hello",
          chat: %{id: 456}
        }
      }
    end

    test "to_atom_keys/1 safely preserves unknown binary keys without exhausting atom table" do
      # Generate a random non-existing key that does not exist in atom table
      random_untrusted_key = "untrusted_dynamic_key_#{:erlang.unique_integer([:positive])}"

      untrusted_payload = %{
        "update_id" => 123,
        random_untrusted_key => "arbitrary_value",
        "nested" => %{
          "nested_untrusted_#{:erlang.unique_integer([:positive])}" => "nested_val",
          "chat" => %{"id" => 789}
        },
        "list_items" => [
          %{"update_id" => 456, "dynamic_key_#{:erlang.unique_integer([:positive])}" => 999}
        ]
      }

      result = TelegramUpdate.to_atom_keys(untrusted_payload)

      # Known keys should be converted to atoms
      assert result[:update_id] == 123
      assert result[:nested][:chat][:id] == 789

      # Unknown keys should remain strings
      assert Map.has_key?(result, random_untrusted_key)
      assert result[random_untrusted_key] == "arbitrary_value"

      # Verify list items
      [first_item] = result[:list_items]
      assert first_item[:update_id] == 456
      assert Enum.any?(Map.keys(first_item), &is_binary/1)
    end

    test "update_id/1 extracts update_id from signal, struct, and map" do
      {:ok, signal} = TelegramUpdate.new(%{update_id: 42})
      assert TelegramUpdate.update_id(signal) == 42
      assert TelegramUpdate.update_id(%Update{update_id: 42}) == 42
      assert TelegramUpdate.update_id(%{"update_id" => 42}) == 42
      assert TelegramUpdate.update_id(%{update_id: 42}) == 42
      assert is_nil(TelegramUpdate.update_id(nil))
    end

    test "message/1 extracts message from signal, struct, and map" do
      msg = %{message_id: 1, text: "msg test"}
      {:ok, signal} = TelegramUpdate.new(%{update_id: 1, message: msg})

      assert TelegramUpdate.message(signal) == msg
      assert TelegramUpdate.message(%Update{update_id: 1, message: %Message{text: "msg test"}}).text == "msg test"
      assert TelegramUpdate.message(%{"update_id" => 1, "message" => %{"text" => "msg test"}}) == %{"text" => "msg test"}
    end

    test "chat_id/1 extracts chat_id across multiple update types" do
      # Regular message
      {:ok, sig1} = TelegramUpdate.new(%{
        update_id: 1,
        message: %{chat: %{id: 1001}}
      })
      assert TelegramUpdate.chat_id(sig1) == 1001

      # Edited message
      {:ok, sig2} = TelegramUpdate.new(%{
        update_id: 2,
        edited_message: %{"chat" => %{"id" => 1002}}
      })
      assert TelegramUpdate.chat_id(sig2) == 1002

      # Channel post
      {:ok, sig3} = TelegramUpdate.new(%{
        update_id: 3,
        channel_post: %{chat: %{id: 1003}}
      })
      assert TelegramUpdate.chat_id(sig3) == 1003

      # Edited channel post
      {:ok, sig3b} = TelegramUpdate.new(%{
        update_id: 31,
        edited_channel_post: %{chat: %{id: 1033}}
      })
      assert TelegramUpdate.chat_id(sig3b) == 1033

      # Callback query
      {:ok, sig4} = TelegramUpdate.new(%{
        update_id: 4,
        callback_query: %{message: %{chat: %{id: 1004}}}
      })
      assert TelegramUpdate.chat_id(sig4) == 1004

      # Callback query with chat_instance
      {:ok, sig4b} = TelegramUpdate.new(%{
        update_id: 41,
        callback_query: %{chat_instance: "inst_123"}
      })
      assert TelegramUpdate.chat_id(sig4b) == "inst_123"

      # My chat member, chat member, chat join request
      {:ok, sig5a} = TelegramUpdate.new(%{update_id: 51, my_chat_member: %{chat: %{id: 1005}}})
      assert TelegramUpdate.chat_id(sig5a) == 1005

      {:ok, sig5b} = TelegramUpdate.new(%{update_id: 52, chat_member: %{chat: %{id: 1006}}})
      assert TelegramUpdate.chat_id(sig5b) == 1006

      {:ok, sig5c} = TelegramUpdate.new(%{update_id: 53, chat_join_request: %{chat: %{id: 1007}}})
      assert TelegramUpdate.chat_id(sig5c) == 1007

      # Struct format
      update_struct = %Update{
        update_id: 5,
        message: %Message{chat: %Chat{id: 1005}}
      }
      assert TelegramUpdate.chat_id(update_struct) == 1005
      assert is_nil(TelegramUpdate.chat_id(%{update_id: 6}))
    end

    test "text/1 extracts text from message, edited_message, channel_post, or callback_query" do
      {:ok, sig1} = TelegramUpdate.new(%{
        update_id: 1,
        message: %{text: "direct message"}
      })
      assert TelegramUpdate.text(sig1) == "direct message"

      {:ok, sig2} = TelegramUpdate.new(%{
        update_id: 2,
        edited_message: %{"text" => "edited text"}
      })
      assert TelegramUpdate.text(sig2) == "edited text"

      {:ok, sig3} = TelegramUpdate.new(%{
        update_id: 3,
        channel_post: %{text: "channel update"}
      })
      assert TelegramUpdate.text(sig3) == "channel update"

      {:ok, sig3b} = TelegramUpdate.new(%{
        update_id: 31,
        edited_channel_post: %{text: "edited channel post text"}
      })
      assert TelegramUpdate.text(sig3b) == "edited channel post text"

      {:ok, sig3c} = TelegramUpdate.new(%{
        update_id: 32,
        message: %{caption: "photo caption text"}
      })
      assert TelegramUpdate.text(sig3c) == "photo caption text"

      {:ok, sig4} = TelegramUpdate.new(%{
        update_id: 4,
        callback_query: %{data: "button_pressed"}
      })
      assert TelegramUpdate.text(sig4) == "button_pressed"

      {:ok, sig4b} = TelegramUpdate.new(%{
        update_id: 41,
        callback_query: %{message: %{text: "text inside cb message"}}
      })
      assert TelegramUpdate.text(sig4b) == "text inside cb message"

      assert is_nil(TelegramUpdate.text(%{update_id: 50}))
    end

    test "callback_query/1 extracts callback query object" do
      cb = %{id: "cb-123", data: "btn_click"}
      {:ok, signal} = TelegramUpdate.new(%{update_id: 1, callback_query: cb})
      assert TelegramUpdate.callback_query(signal) == cb

      assert TelegramUpdate.callback_query(%{"update_id" => 1, "callback_query" => %{"id" => "cb-456"}}) ==
               %{"id" => "cb-456"}
    end
  end

  describe "to_atom_keys and to_struct edge cases" do
    test "new/1 with %Types.Update{} inside payload field and scalar payload" do
      update = %Update{update_id: 888, message: %Message{text: "nested struct"}}
      assert {:ok, signal} = TelegramUpdate.new(%{payload: update})
      assert signal.payload.update_id == 888

      assert {:ok, sig_str} = TelegramUpdate.new(%{"payload" => update})
      assert sig_str.payload.update_id == 888

      # Non-map payload
      assert {:error, _} = TelegramUpdate.new(%{payload: "invalid_scalar_payload"})
    end

    test "to_atom_keys and to_struct edge cases" do
      assert is_nil(TelegramUpdate.to_struct("not_a_map"))
      assert is_nil(TelegramUpdate.to_struct(12345))
      assert is_nil(TelegramUpdate.to_struct(:atom_val))

      assert TelegramUpdate.to_atom_keys(%User{id: 100}) == %{id: 100, is_bot: nil, first_name: nil, last_name: nil, username: nil, language_code: nil, can_join_groups: nil, can_read_all_group_messages: nil, supports_inline_queries: nil}
      assert TelegramUpdate.to_atom_keys(%{123 => "numeric_key", {:tuple, :key} => "tuple_val"}) == %{123 => "numeric_key", {:tuple, :key} => "tuple_val"}
      assert TelegramUpdate.to_atom_keys("scalar_string") == "scalar_string"
      assert TelegramUpdate.to_atom_keys(42) == 42
      assert is_nil(TelegramUpdate.to_atom_keys(nil))

      # Extractors with nil / invalid targets
      assert TelegramUpdate.chat_id(%{"message" => %{"chat" => %{id: 777}}}) == 777
      assert is_nil(TelegramUpdate.chat_id(nil))
      assert is_nil(TelegramUpdate.chat_id("not_a_map"))
      assert is_nil(TelegramUpdate.text(nil))
      assert is_nil(TelegramUpdate.text("not_a_map"))
      assert is_nil(TelegramUpdate.message(nil))
      assert is_nil(TelegramUpdate.callback_query(nil))
    end
  end
end

