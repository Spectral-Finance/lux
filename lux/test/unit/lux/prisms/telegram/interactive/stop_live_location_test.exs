defmodule Lux.Prisms.Telegram.Interactive.StopLiveLocationTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.StopLiveLocation

  @chat_id 123_456_789
  @message_id 42
  @inline_message_id "CAAqrxJRAqABAZaiqJ4sAJtvlCQI"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully stops a live location with chat_id and message_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "edit_date" => 1_617_123_459,
            "location" => %{
              "latitude" => 37.7858,
              "longitude" => -122.4064,
              "live_period" => 0
            }
          }
        }))
      end)

      assert {:ok, %{stopped: true, message_id: @message_id, chat_id: @chat_id}} =
               StopLiveLocation.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully stops a live location with inline_message_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["inline_message_id"] == @inline_message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{stopped: true, inline_message_id: @inline_message_id}} =
               StopLiveLocation.handler(
                 %{
                   inline_message_id: @inline_message_id,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully stops a live location with a reply_markup" do
      reply_markup = %{
        "inline_keyboard" => [
          [%{"text" => "View History", "callback_data" => "view_history"}]
        ]
      }

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["message_id"] == @message_id
        assert decoded_body["reply_markup"] == reply_markup

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "edit_date" => 1_617_123_459,
            "location" => %{
              "latitude" => 37.7858,
              "longitude" => -122.4064,
              "live_period" => 0
            },
            "reply_markup" => %{
              "inline_keyboard" => [
                [%{"text" => "View History", "callback_data" => "view_history"}]
              ]
            }
          }
        }))
      end)

      assert {:ok, %{stopped: true, message_id: @message_id, chat_id: @chat_id}} =
               StopLiveLocation.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   reply_markup: reply_markup,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates message identification parameters" do
      result = StopLiveLocation.handler(%{}, @agent_ctx)
      assert result == {:error, "Missing or invalid message identifier: Either (chat_id and message_id) or inline_message_id must be provided"}

      result = StopLiveLocation.handler(%{chat_id: @chat_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid message identifier: Either (chat_id and message_id) or inline_message_id must be provided"}

      result = StopLiveLocation.handler(%{message_id: @message_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid message identifier: Either (chat_id and message_id) or inline_message_id must be provided"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: message to edit not found"
        }))
      end)

      assert {:error, "Failed to stop live location: Bad Request: message to edit not found (HTTP 400)"} =
               StopLiveLocation.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = StopLiveLocation.view()
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
      assert Map.has_key?(prism.input_schema.properties, :inline_message_id)
      assert Map.has_key?(prism.input_schema.properties, :reply_markup)
    end

    test "validates output schema" do
      prism = StopLiveLocation.view()
      assert prism.output_schema.required == ["stopped"]
      assert Map.has_key?(prism.output_schema.properties, :stopped)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :inline_message_id)
    end
  end
end
