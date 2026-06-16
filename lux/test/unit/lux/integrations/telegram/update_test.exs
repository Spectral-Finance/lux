defmodule Lux.Integrations.Telegram.UpdateTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Update

  describe "parse/1" do
    test "successfully parses text message update" do
      raw = %{
        "update_id" => 10000,
        "message" => %{
          "message_id" => 1,
          "chat" => %{"id" => 123456},
          "from" => %{"id" => 98765},
          "text" => "Hello World"
        }
      }

      parsed = Update.parse(raw)

      assert parsed.id == 10000
      assert parsed.type == :message
      assert parsed.chat_id == 123456
      assert parsed.user_id == 98765
      assert parsed.text == "Hello World"
      assert parsed.payload == raw["message"]
      assert parsed.raw == raw
    end

    test "successfully parses caption message update" do
      raw = %{
        "update_id" => 10001,
        "message" => %{
          "message_id" => 2,
          "chat" => %{"id" => 123456},
          "from" => %{"id" => 98765},
          "caption" => "Attached photo description"
        }
      }

      parsed = Update.parse(raw)

      assert parsed.id == 10001
      assert parsed.type == :message
      assert parsed.text == "Attached photo description"
    end

    test "successfully parses callback query update" do
      raw = %{
        "update_id" => 20000,
        "callback_query" => %{
          "id" => "query_id_123",
          "from" => %{"id" => 98765},
          "message" => %{
            "message_id" => 3,
            "chat" => %{"id" => 123456}
          },
          "data" => "button_clicked_payload"
        }
      }

      parsed = Update.parse(raw)

      assert parsed.id == 20000
      assert parsed.type == :callback_query
      assert parsed.chat_id == 123456
      assert parsed.user_id == 98765
      assert parsed.text == "button_clicked_payload"
    end

    test "successfully parses inline query update" do
      raw = %{
        "update_id" => 30000,
        "inline_query" => %{
          "id" => "query_id_456",
          "from" => %{"id" => 98765},
          "query" => "search query text"
        }
      }

      parsed = Update.parse(raw)

      assert parsed.id == 30000
      assert parsed.type == :inline_query
      assert parsed.chat_id == nil
      assert parsed.user_id == 98765
      assert parsed.text == "search query text"
    end

    test "successfully parses poll update" do
      raw = %{
        "update_id" => 40000,
        "poll" => %{
          "id" => "poll_id_789",
          "question" => "What is your favorite framework?",
          "options" => []
        }
      }

      parsed = Update.parse(raw)

      assert parsed.id == 40000
      assert parsed.type == :poll
      assert parsed.text == "What is your favorite framework?"
    end

    test "handles unknown update structure" do
      raw = %{
        "update_id" => 99999,
        "weird_new_field" => %{
          "something" => "else"
        }
      }

      parsed = Update.parse(raw)

      assert parsed.id == 99999
      assert parsed.type == :unknown
      assert parsed.chat_id == nil
      assert parsed.text == nil
    end

    test "safely handles missing sub-fields (no exception)" do
      raw = %{
        "update_id" => 10005,
        "message" => %{
          # missing chat, from, and text
        }
      }

      parsed = Update.parse(raw)

      assert parsed.id == 10005
      assert parsed.type == :message
      assert parsed.chat_id == nil
      assert parsed.user_id == nil
      assert parsed.text == nil
    end

    test "supports atom keys" do
      raw = %{
        update_id: 10000,
        message: %{
          message_id: 1,
          chat: %{id: 123456},
          from: {:%{}, [], [id: 98765]}, # struct-like mock or simple map
          text: "Atom key text"
        }
      }

      # Let's use clean map to be safe
      cleaned = %{
        update_id: 10000,
        message: %{
          message_id: 1,
          chat: %{id: 123456},
          from: %{id: 98765},
          text: "Atom key text"
        }
      }

      parsed = Update.parse(cleaned)

      assert parsed.id == 10000
      assert parsed.type == :message
      assert parsed.chat_id == 123456
      assert parsed.user_id == 98765
      assert parsed.text == "Atom key text"
    end

    test "successfully parses edited_message update" do
      raw = %{
        "update_id" => 10002,
        "edited_message" => %{
          "message_id" => 2,
          "chat" => %{"id" => 123456},
          "from" => %{"id" => 98765},
          "text" => "Edited text"
        }
      }
      parsed = Update.parse(raw)
      assert parsed.id == 10002
      assert parsed.type == :edited_message
      assert parsed.chat_id == 123456
      assert parsed.user_id == 98765
      assert parsed.text == "Edited text"
    end

    test "successfully parses channel_post update" do
      raw = %{
        "update_id" => 10003,
        "channel_post" => %{
          "message_id" => 3,
          "chat" => %{"id" => -100123456},
          "text" => "Channel post text"
        }
      }
      parsed = Update.parse(raw)
      assert parsed.id == 10003
      assert parsed.type == :channel_post
      assert parsed.chat_id == -100123456
      assert parsed.text == "Channel post text"
    end

    test "successfully parses edited_channel_post update" do
      raw = %{
        "update_id" => 10004,
        "edited_channel_post" => %{
          "message_id" => 4,
          "chat" => %{"id" => -100123456},
          "text" => "Edited channel post text"
        }
      }
      parsed = Update.parse(raw)
      assert parsed.id == 10004
      assert parsed.type == :edited_channel_post
      assert parsed.chat_id == -100123456
      assert parsed.text == "Edited channel post text"
    end

    test "successfully parses chosen_inline_result update" do
      raw = %{
        "update_id" => 50000,
        "chosen_inline_result" => %{
          "result_id" => "result_1",
          "from" => %{"id" => 98765},
          "query" => "inline query search"
        }
      }
      parsed = Update.parse(raw)
      assert parsed.type == :chosen_inline_result
      assert parsed.user_id == 98765
      assert parsed.text == "inline query search"
    end

    test "successfully parses shipping_query update" do
      raw = %{
        "update_id" => 60000,
        "shipping_query" => %{
          "id" => "ship_1",
          "from" => %{"id" => 98765}
        }
      }
      parsed = Update.parse(raw)
      assert parsed.type == :shipping_query
      assert parsed.user_id == 98765
    end

    test "successfully parses pre_checkout_query update" do
      raw = %{
        "update_id" => 70000,
        "pre_checkout_query" => %{
          "id" => "checkout_1",
          "from" => %{"id" => 98765}
        }
      }
      parsed = Update.parse(raw)
      assert parsed.type == :pre_checkout_query
      assert parsed.user_id == 98765
    end

    test "successfully parses poll_answer update" do
      raw = %{
        "update_id" => 80000,
        "poll_answer" => %{
          "poll_id" => "poll_1",
          "user" => %{"id" => 98765}
        }
      }
      parsed = Update.parse(raw)
      assert parsed.type == :poll_answer
      assert parsed.user_id == 98765
    end

    test "successfully parses my_chat_member update" do
      raw = %{
        "update_id" => 90000,
        "my_chat_member" => %{
          "chat" => %{"id" => 123456},
          "from" => %{"id" => 98765}
        }
      }
      parsed = Update.parse(raw)
      assert parsed.type == :my_chat_member
      assert parsed.chat_id == 123456
      assert parsed.user_id == 98765
    end

    test "successfully parses chat_member update" do
      raw = %{
        "update_id" => 90001,
        "chat_member" => %{
          "chat" => %{"id" => 123456},
          "from" => %{"id" => 98765}
        }
      }
      parsed = Update.parse(raw)
      assert parsed.type == :chat_member
      assert parsed.chat_id == 123456
      assert parsed.user_id == 98765
    end

    test "successfully parses chat_join_request update" do
      raw = %{
        "update_id" => 90002,
        "chat_join_request" => %{
          "chat" => %{"id" => 123456},
          "from" => %{"id" => 98765}
        }
      }
      parsed = Update.parse(raw)
      assert parsed.type == :chat_join_request
      assert parsed.chat_id == 123456
      assert parsed.user_id == 98765
    end

    test "handles callback_query without message" do
      raw = %{
        "update_id" => 20001,
        "callback_query" => %{
          "id" => "query_id_123",
          "from" => %{"id" => 98765},
          "data" => "button_clicked"
        }
      }
      parsed = Update.parse(raw)
      assert parsed.type == :callback_query
      assert parsed.chat_id == nil
      assert parsed.text == "button_clicked"
    end

    test "handles poll_answer without user" do
      raw = %{
        "update_id" => 80001,
        "poll_answer" => %{
          "poll_id" => "poll_1"
        }
      }
      parsed = Update.parse(raw)
      assert parsed.type == :poll_answer
      assert parsed.user_id == nil
    end

    test "handles non-map values in update fields gracefully" do
      assert Update.parse(%{"update_id" => 1, "message" => "not_a_map"}).chat_id == nil
    end
  end
end
