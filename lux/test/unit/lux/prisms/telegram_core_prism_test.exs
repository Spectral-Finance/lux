defmodule Lux.Prisms.TelegramCorePrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.TelegramCorePrism

  describe "handler/2 actions" do
    test "gets bot info via Prism" do
      plug = fn conn ->
        assert conn.request_path == "/botmock_token/getMe"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{"id" => 12345, "username" => "agent_bot"}
          })
        )
      end

      {:ok, response} =
        TelegramCorePrism.run(%{
          action: "get_me",
          payload: %{
            token: "mock_token",
            plug: plug
          }
        })

      assert response.action == "get_me"
      assert response.result["result"]["username"] == "agent_bot"
    end

    test "sends message via Prism" do
      plug = fn conn ->
        assert conn.request_path == "/botmock_token/sendMessage"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["text"] == "Autonomous message"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{"message_id" => 101, "text" => decoded["text"]}
          })
        )
      end

      {:ok, response} =
        TelegramCorePrism.run(%{
          action: "send_message",
          payload: %{
            chat_id: 99999,
            text: "Autonomous message",
            token: "mock_token",
            plug: plug
          }
        })

      assert response.action == "send_message"
      assert response.result["result"]["message_id"] == 101
    end

    test "edits message via Prism" do
      plug = fn conn ->
        assert conn.request_path == "/botmock_token/editMessageText"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{"message_id" => 101, "text" => "Updated text"}
          })
        )
      end

      {:ok, response} =
        TelegramCorePrism.run(%{
          action: "edit_message",
          payload: %{
            chat_id: 99999,
            message_id: 101,
            text: "Updated text",
            token: "mock_token",
            plug: plug
          }
        })

      assert response.action == "edit_message"
      assert response.result["result"]["text"] == "Updated text"
    end

    test "deletes message via Prism" do
      plug = fn conn ->
        assert conn.request_path == "/botmock_token/deleteMessage"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => true
          })
        )
      end

      {:ok, response} =
        TelegramCorePrism.run(%{
          action: "delete_message",
          payload: %{
            chat_id: 99999,
            message_id: 101,
            token: "mock_token",
            plug: plug
          }
        })

      assert response.action == "delete_message"
      assert response.result["result"] == true
    end

    test "registers bot token securely via Prism" do
      valid_token = "123456789:ABCdefGHIjklMNOpqrSTUvwxYZ123456789"

      {:ok, response} =
        TelegramCorePrism.run(%{
          action: "register_bot_token",
          payload: %{
            name: "support_bot",
            token: valid_token,
            passphrase: "encryption_key_123"
          }
        })

      assert response.action == "register_bot_token"
      assert response.result.bot.name == "support_bot"
      assert response.result.masked_token == "123456789:ABCd...6789"
    end

    test "enqueues message into priority queue via Prism" do
      {:ok, response} =
        TelegramCorePrism.run(%{
          action: "enqueue_message",
          payload: %{
            chat_id: 12345,
            priority: :high,
            message: %{"text" => "Critical priority notification"}
          }
        })

      assert response.action == "enqueue_message"
      assert response.result.item.priority == :high
      assert response.result.pending == 1
    end

    test "handles unknown action" do
      assert {:error, reason} =
               TelegramCorePrism.run(%{
                 action: "unsupported_action"
               })

      assert String.contains?(reason, "Unknown action: unsupported_action")
    end
  end
end
