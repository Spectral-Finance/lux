defmodule Lux.Telegram.TypesTest do
  use UnitAPICase, async: true

  alias Lux.Telegram.Types
  alias Lux.Telegram.Types.{
    Chat,
    File,
    ForceReply,
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    KeyboardButton,
    Message,
    ReplyKeyboardMarkup,
    ReplyKeyboardRemove,
    Response,
    Update,
    User,
    WebhookInfo
  }

  describe "User.from_map/1" do
    test "parses map with string and atom keys" do
      map = %{
        "id" => 123,
        "is_bot" => false,
        "first_name" => "Alice",
        "last_name" => "Smith",
        "username" => "alice_smith",
        "language_code" => "en",
        "can_join_groups" => true,
        "can_read_all_group_messages" => false,
        "supports_inline_queries" => true
      }

      user = User.from_map(map)
      assert user.id == 123
      assert user.first_name == "Alice"
      assert user.is_bot == false
      assert user.username == "alice_smith"
      assert user.supports_inline_queries == true

      # Struct passthrough
      assert User.from_map(user) == user
      # nil passthrough
      assert User.from_map(nil) == nil
      # non-map
      assert User.from_map("invalid") == nil
    end
  end

  describe "Chat.from_map/1" do
    test "parses chat map" do
      map = %{
        id: 456,
        type: "supergroup",
        title: "Elixir Group",
        username: "elixir_grp",
        first_name: "Group",
        last_name: "Admin",
        is_forum: true
      }

      chat = Chat.from_map(map)
      assert chat.id == 456
      assert chat.type == "supergroup"
      assert chat.is_forum == true

      assert Chat.from_map(chat) == chat
      assert Chat.from_map(nil) == nil
      assert Chat.from_map(123) == nil
    end
  end

  describe "Message.from_map/1" do
    test "parses message map with nested user, chat, and reply_to_message" do
      map = %{
        "message_id" => 10,
        "message_thread_id" => 1,
        "from" => %{"id" => 123, "first_name" => "Alice"},
        "date" => 1_700_000_000,
        "chat" => %{"id" => 456, "type" => "private"},
        "text" => "Hello world",
        "reply_to_message" => %{
          "message_id" => 9,
          "text" => "Original message"
        }
      }

      msg = Message.from_map(map)
      assert msg.message_id == 10
      assert msg.from.first_name == "Alice"
      assert msg.chat.id == 456
      assert msg.reply_to_message.message_id == 9

      assert Message.from_map(msg) == msg
      assert Message.from_map(nil) == nil
      assert Message.from_map("invalid") == nil
    end
  end

  describe "File.from_map/1" do
    test "parses file map" do
      map = %{
        "file_id" => "f123",
        "file_unique_id" => "fu123",
        "file_size" => 2048,
        "file_path" => "photos/file_1.jpg"
      }

      file = File.from_map(map)
      assert file.file_id == "f123"
      assert file.file_path == "photos/file_1.jpg"

      assert File.from_map(file) == file
      assert File.from_map(nil) == nil
      assert File.from_map(123) == nil
    end
  end

  describe "WebhookInfo.from_map/1" do
    test "parses webhook info map" do
      map = %{
        "url" => "https://example.com/hook",
        "has_custom_certificate" => false,
        "pending_update_count" => 0,
        "ip_address" => "1.1.1.1",
        "last_error_date" => 1_700_000_000,
        "last_error_message" => "Connection refused",
        "last_synchronization_error_date" => 1_700_000_001,
        "max_connections" => 40,
        "allowed_updates" => ["message", "callback_query"]
      }

      info = WebhookInfo.from_map(map)
      assert info.url == "https://example.com/hook"
      assert info.max_connections == 40
      assert info.allowed_updates == ["message", "callback_query"]

      assert WebhookInfo.from_map(info) == info
      assert WebhookInfo.from_map(nil) == nil
      assert WebhookInfo.from_map("invalid") == nil
    end
  end

  describe "Response.from_map/1" do
    test "parses response map" do
      map = %{
        "ok" => true,
        "result" => %{"message_id" => 1},
        "error_code" => nil,
        "description" => nil,
        "parameters" => %{"retry_after" => 5}
      }

      resp = Response.from_map(map)
      assert resp.ok == true
      assert resp.parameters["retry_after"] == 5

      assert Response.from_map(resp) == resp
      assert Response.from_map(nil) == nil
      assert Response.from_map(123) == nil
    end
  end

  describe "Keyboards structs from_map" do
    test "InlineKeyboardButton and InlineKeyboardMarkup" do
      btn_map = %{
        "text" => "Click",
        "url" => "https://example.com",
        "callback_data" => "cb_1",
        "web_app" => %{"url" => "https://app.com"},
        "login_url" => %{"url" => "https://login.com"},
        "switch_inline_query" => "query",
        "switch_inline_query_current_chat" => "current",
        "switch_inline_query_chosen_chat" => %{"allow_user_chats" => true},
        "callback_game" => %{},
        "pay" => true
      }

      btn = InlineKeyboardButton.from_map(btn_map)
      assert btn.text == "Click"
      assert btn.callback_data == "cb_1"
      assert btn.pay == true

      assert InlineKeyboardButton.from_map(btn) == btn
      assert InlineKeyboardButton.from_map(nil) == nil
      assert InlineKeyboardButton.from_map("invalid") == nil

      kb_map = %{
        "inline_keyboard" => [[btn_map, btn]]
      }

      kb = InlineKeyboardMarkup.from_map(kb_map)
      assert length(kb.inline_keyboard) == 1
      assert length(hd(kb.inline_keyboard)) == 2

      assert InlineKeyboardMarkup.from_map(kb) == kb
      assert InlineKeyboardMarkup.from_map(nil) == nil
      assert InlineKeyboardMarkup.from_map(123) == nil
    end

    test "KeyboardButton and ReplyKeyboardMarkup" do
      btn_map = %{
        "text" => "Send Location",
        "request_users" => %{"max_quantity" => 1},
        "request_chat" => %{"chat_is_channel" => false},
        "request_contact" => true,
        "request_location" => true,
        "request_poll" => %{"type" => "quiz"},
        "web_app" => %{"url" => "https://app.com"}
      }

      btn = KeyboardButton.from_map(btn_map)
      assert btn.text == "Send Location"
      assert btn.request_contact == true

      assert KeyboardButton.from_map(btn) == btn
      assert KeyboardButton.from_map(nil) == nil
      assert KeyboardButton.from_map("invalid") == nil

      reply_map = %{
        "keyboard" => [[btn_map, btn]],
        "is_persistent" => true,
        "resize_keyboard" => true,
        "one_time_keyboard" => true,
        "input_field_placeholder" => "Placeholder",
        "selective" => true
      }

      reply_kb = ReplyKeyboardMarkup.from_map(reply_map)
      assert reply_kb.resize_keyboard == true
      assert reply_kb.selective == true

      assert ReplyKeyboardMarkup.from_map(reply_kb) == reply_kb
      assert ReplyKeyboardMarkup.from_map(nil) == nil
      assert ReplyKeyboardMarkup.from_map(123) == nil
    end

    test "ReplyKeyboardRemove and ForceReply" do
      remove_map = %{"remove_keyboard" => true, "selective" => true}
      remove = ReplyKeyboardRemove.from_map(remove_map)
      assert remove.remove_keyboard == true
      assert remove.selective == true
      assert ReplyKeyboardRemove.from_map(remove) == remove
      assert ReplyKeyboardRemove.from_map(nil) == nil
      assert ReplyKeyboardRemove.from_map("invalid") == nil

      force_map = %{"force_reply" => true, "input_field_placeholder" => "Type here", "selective" => false}
      force = ForceReply.from_map(force_map)
      assert force.force_reply == true
      assert force.input_field_placeholder == "Type here"
      assert ForceReply.from_map(force) == force
      assert ForceReply.from_map(nil) == nil
      assert ForceReply.from_map(123) == nil
    end
  end

  describe "Update.from_map/1 and Update.to_map/1" do
    test "Update with various update payloads" do
      up_map = %{
        "update_id" => 1001,
        "message" => %{"message_id" => 10, "chat" => %{"id" => 1, "type" => "private"}},
        "edited_message" => %{"message_id" => 11, "chat" => %{"id" => 1, "type" => "private"}},
        "channel_post" => %{"message_id" => 12, "chat" => %{"id" => 2, "type" => "channel"}},
        "edited_channel_post" => %{"message_id" => 13, "chat" => %{"id" => 2, "type" => "channel"}},
        "inline_query" => %{"id" => "iq1"},
        "chosen_inline_result" => %{"result_id" => "cir1"},
        "callback_query" => %{"id" => "cb1"},
        "shipping_query" => %{"id" => "sq1"},
        "pre_checkout_query" => %{"id" => "pcq1"},
        "poll" => %{"id" => "p1", "question" => "Q", "options" => []},
        "poll_answer" => %{"poll_id" => "p1", "option_ids" => [0]},
        "my_chat_member" => %{"chat" => %{"id" => 3}, "date" => 1_700_000_000},
        "chat_member" => %{"chat" => %{"id" => 3}, "date" => 1_700_000_000},
        "chat_join_request" => %{"chat" => %{"id" => 4}, "date" => 1_700_000_000}
      }

      update = Update.from_map(up_map)
      assert update.update_id == 1001
      assert update.message.message_id == 10
      assert update.edited_message.message_id == 11
      assert update.channel_post.message_id == 12
      assert update.edited_channel_post.message_id == 13
      assert update.inline_query["id"] == "iq1"
      assert update.chosen_inline_result["result_id"] == "cir1"
      assert update.callback_query["id"] == "cb1"
      assert update.shipping_query["id"] == "sq1"
      assert update.pre_checkout_query["id"] == "pcq1"
      assert update.poll["id"] == "p1"
      assert update.poll_answer["poll_id"] == "p1"
      assert update.my_chat_member["chat"]["id"] == 3
      assert update.chat_member["chat"]["id"] == 3
      assert update.chat_join_request["chat"]["id"] == 4

      assert Update.from_map(update) == update
      assert Update.from_map(nil) == nil
      assert Update.from_map(12345) == nil

      # Update.to_map
      assert %{update_id: 1001} = Update.to_map(update)
      assert is_nil(Update.to_map(nil))
    end
  end

  describe "Types.to_map/1 and Types.from_map/2" do
    test "to_map strips nils and transforms nested structs" do
      user = %User{id: 123, first_name: "Bob", is_bot: false}
      map = Types.to_map(user)
      assert map == %{id: 123, first_name: "Bob", is_bot: false}

      list = [user, %Chat{id: 456, type: "private"}]
      assert [%{id: 123, first_name: "Bob", is_bot: false}, %{id: 456, type: "private"}] = Types.to_map(list)

      nested_map = %{user: user, count: 5}
      assert %{user: %{id: 123, first_name: "Bob", is_bot: false}, count: 5} = Types.to_map(nested_map)

      assert Types.to_map(nil) == nil
      assert Types.to_map(42) == 42
      assert Types.to_map("string") == "string"
    end

    test "from_map/2 dispatches to specific module or returns raw map" do
      assert %User{id: 10} = Types.from_map(User, %{"id" => 10})
      assert %Chat{id: 20} = Types.from_map(Chat, %{"id" => 20})
      assert %Message{message_id: 30} = Types.from_map(Message, %{"message_id" => 30})
      assert %Update{update_id: 40} = Types.from_map(Update, %{"update_id" => 40})
      assert %File{file_id: "f"} = Types.from_map(File, %{"file_id" => "f"})
      assert %WebhookInfo{url: "u"} = Types.from_map(WebhookInfo, %{"url" => "u"})
      assert %Response{ok: true} = Types.from_map(Response, %{"ok" => true})
      assert %{unknown: "value"} = Types.from_map(UnknownModule, %{unknown: "value"})
    end

    test "Jason encoding for Types structs" do
      user = %User{id: 99, first_name: "JasonUser"}
      encoded = Jason.encode!(user)
      assert Jason.decode!(encoded) == %{"id" => 99, "first_name" => "JasonUser"}
    end

    test "fetch_key with nil or non-map returns nil" do
      assert is_nil(Lux.Telegram.Types.fetch_key(nil, :key))
      assert is_nil(Lux.Telegram.Types.fetch_key("not_a_map", :key))
    end
  end
end

