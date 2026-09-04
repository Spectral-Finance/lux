defmodule Lux.Telegram.MessagingTest do
  use UnitAPICase, async: true

  alias Lux.Telegram.Keyboards
  alias Lux.Telegram.Messaging

  describe "send_message/3" do
    test "sends a message to a chat" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        send(test_pid, {:request, conn.request_path, params})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 42, "text" => "Hello"}}))
      end

      assert {:ok, %{"ok" => true, "result" => %{"message_id" => 42}}} =
               Messaging.send_message(123_456, "Hello", plug: plug, token: "tok123")

      assert_receive {:request, "/bottok123/sendMessage", %{"chat_id" => 123_456, "text" => "Hello"}}
    end

    test "normalizes reply_markup with Keyboards struct" do
      test_pid = self()

      keyboard = Keyboards.inline_keyboard([
        [Keyboards.inline_button("Button", "btn_data")]
      ])

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        send(test_pid, {:request, conn.request_path, params})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 43}}))
      end

      assert {:ok, _} =
               Messaging.send_message(123_456, "Choose", %{
                 reply_markup: keyboard,
                 plug: plug,
                 token: "tok123"
               })

      assert_receive {:request, "/bottok123/sendMessage", %{
        "chat_id" => 123_456,
        "text" => "Choose",
        "reply_markup" => %{
          "inline_keyboard" => [[%{"text" => "Button", "callback_data" => "btn_data"}]]
        }
      }}
    end
  end

  describe "edit_message_text" do
    test "edits message text with chat_id and message_id" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        send(test_pid, {:request, conn.request_path, params})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 42, "text" => "Edited"}}))
      end

      assert {:ok, _} =
               Messaging.edit_message_text(123_456, 42, "Edited", plug: plug, token: "tok123")

      assert_receive {:request, "/bottok123/editMessageText", %{"chat_id" => 123_456, "message_id" => 42, "text" => "Edited"}}
    end

    test "edits inline message text" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        send(test_pid, {:request, conn.request_path, params})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} =
               Messaging.edit_message_text("inline_12345", "New text", [plug: plug, token: "tok123"], %{})

      assert_receive {:request, "/bottok123/editMessageText", %{"inline_message_id" => "inline_12345", "text" => "New text"}}
    end

    test "edits message text with nil chat_id and message_id" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        send(test_pid, {:request, conn.request_path, params})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} =
               Messaging.edit_message_text(nil, 42, "Edited", plug: plug, token: "tok123")

      assert_receive {:request, "/bottok123/editMessageText", %{"message_id" => 42, "text" => "Edited"}}
    end

    test "edits message text with both nil chat_id and nil message_id" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        send(test_pid, {:request, conn.request_path, params})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} =
               Messaging.edit_message_text(nil, nil, "Edited", plug: plug, token: "tok123")

      assert_receive {:request, "/bottok123/editMessageText", %{"text" => "Edited"}}
    end
  end

  describe "delete_message/3" do
    test "deletes a message" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        send(test_pid, {:request, conn.request_path, params})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, %{"ok" => true, "result" => true}} =
               Messaging.delete_message(123_456, 42, plug: plug, token: "tok123")

      assert_receive {:request, "/bottok123/deleteMessage", %{"chat_id" => 123_456, "message_id" => 42}}
    end
  end

  describe "copy_message/4" do
    test "copies a message from one chat to another" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        send(test_pid, {:request, conn.request_path, params})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 99}}))
      end

      assert {:ok, %{"ok" => true, "result" => %{"message_id" => 99}}} =
               Messaging.copy_message(123_456, 789_012, 42, plug: plug, token: "tok123")

      assert_receive {:request, "/bottok123/copyMessage", %{"chat_id" => 123_456, "from_chat_id" => 789_012, "message_id" => 42}}
    end
  end

  describe "forward_message/4" do
    test "forwards a message from one chat to another" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        send(test_pid, {:request, conn.request_path, params})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 100}}))
      end

      assert {:ok, %{"ok" => true, "result" => %{"message_id" => 100}}} =
               Messaging.forward_message(123_456, 789_012, 42, plug: plug, token: "tok123")

      assert_receive {:request, "/bottok123/forwardMessage", %{"chat_id" => 123_456, "from_chat_id" => 789_012, "message_id" => 42}}
    end
  end

  describe "messaging default arities" do
    test "edits message text with string message_id and keyword opts" do
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} = Messaging.edit_message_text(123, "42", "Updated", [token: "tok", plug: plug])
    end

    test "send_message, delete_message, copy_message, forward_message 2/3 arities" do
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1}}))
      end

      assert {:ok, _} = Messaging.send_message(123, "hello", token: "tok", plug: plug)
      assert {:ok, _} = Messaging.edit_message_text(123, 1, "hello", token: "tok", plug: plug)
      assert {:ok, _} = Messaging.edit_message_text(nil, nil, "hello", token: "tok", plug: plug)
      assert {:ok, _} = Messaging.edit_message_text(:not_int_or_str, :not_int_or_str, "hello", token: "tok", plug: plug)
      assert {:ok, _} = Messaging.delete_message(123, 1, token: "tok", plug: plug)
      assert {:ok, _} = Messaging.copy_message(123, 456, 1, token: "tok", plug: plug)
      assert {:ok, _} = Messaging.forward_message(123, 456, 1, token: "tok", plug: plug)
    end

    test "messaging helpers without any options" do
      Req.Test.expect(TelegramClientMock, 6, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1}}))
      end)

      assert {:ok, _} = Messaging.send_message(123, "hello")
      assert {:ok, _} = Messaging.edit_message_text(123, 1, "hello")
      assert {:ok, _} = Messaging.edit_message_text("inline_99", "hello")
      assert {:ok, _} = Messaging.delete_message(123, 1)
      assert {:ok, _} = Messaging.copy_message(123, 456, 1)
      assert {:ok, _} = Messaging.forward_message(123, 456, 1)
    end

    test "edit_message_text with inline_id and 3 arguments" do
      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["inline_message_id"] == "inl_42"
        assert params["text"] == "inline updated"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      assert {:ok, _} = Messaging.edit_message_text("inl_42", "inline updated", [token: "tok", plug: plug])
    end
  end
end


