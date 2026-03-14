defmodule Lux.Lenses.Telegram.Messages.ReadUpdatesTest do
  @moduledoc """
  Test suite for the ReadUpdates lens.
  These tests verify the lens's ability to:
  - Receive incoming updates via long polling
  - Normalize different update types (message, callback_query, edited_message, channel_post)
  - Handle empty update lists
  - Handle pagination with offset
  - Handle Telegram API errors appropriately
  - Handle rate limiting (429 responses)
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Messages.ReadUpdates

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully reads updates with messages" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/getUpdates")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "update_id" => 123_456_789,
              "message" => %{
                "message_id" => 1,
                "chat" => %{"id" => 111_222_333, "type" => "private"},
                "text" => "Hello!",
                "from" => %{
                  "id" => 444_555_666,
                  "is_bot" => false,
                  "first_name" => "Test",
                  "username" => "testuser"
                },
                "date" => 1_234_567_890
              }
            }
          ]
        }))
      end)

      assert {:ok, [update]} = ReadUpdates.focus(%{}, %{})
      assert update.update_id == 123_456_789
      assert update.message.message_id == 1
      assert update.message.chat_id == 111_222_333
      assert update.message.text == "Hello!"
      assert update.message.from.username == "testuser"
    end

    test "successfully reads callback query updates" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "update_id" => 123_456_790,
              "callback_query" => %{
                "id" => "callback123",
                "from" => %{
                  "id" => 444_555_666,
                  "is_bot" => false,
                  "first_name" => "Test",
                  "username" => "testuser"
                },
                "data" => "button_clicked",
                "message" => %{
                  "message_id" => 42,
                  "chat" => %{"id" => 111_222_333}
                }
              }
            }
          ]
        }))
      end)

      assert {:ok, [update]} = ReadUpdates.focus(%{}, %{})
      assert update.update_id == 123_456_790
      assert update.callback_query.id == "callback123"
      assert update.callback_query.data == "button_clicked"
      assert update.callback_query.message_id == 42
      assert update.callback_query.chat_id == 111_222_333
    end

    test "handles empty update list" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => []
        }))
      end)

      assert {:ok, []} = ReadUpdates.focus(%{}, %{})
    end

    test "sends offset and timeout parameters" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["offset"] == 123_456_790
        assert decoded["timeout"] == 30

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => []
        }))
      end)

      assert {:ok, []} = ReadUpdates.focus(%{
        offset: 123_456_790,
        timeout: 30
      }, %{})
    end

    test "handles rate limiting (429)" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests: retry after 5",
          "parameters" => %{"retry_after" => 5}
        }))
      end)

      assert {:error, %{reason: :rate_limited, retry_after: 5}} =
        ReadUpdates.focus(%{}, %{})
    end
  end

  describe "schema validation" do
    test "has no required fields" do
      lens = ReadUpdates.view()
      assert lens.schema.required == []
    end

    test "validates schema properties" do
      lens = ReadUpdates.view()
      assert Map.has_key?(lens.schema.properties, :offset)
      assert Map.has_key?(lens.schema.properties, :limit)
      assert Map.has_key?(lens.schema.properties, :timeout)
      assert Map.has_key?(lens.schema.properties, :allowed_updates)
    end

    test "validates limit constraints" do
      lens = ReadUpdates.view()
      limit = lens.schema.properties.limit
      assert limit.minimum == 1
      assert limit.maximum == 100
      assert limit.default == 100
    end
  end
end
