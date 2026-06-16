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
  end
end
