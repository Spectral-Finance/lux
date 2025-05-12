defmodule Lux.Prisms.Telegram.Media.SendContactTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Media.SendContact

  @bot_token "test-integration-telegram-bot-token"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "sends a contact with required parameters" do
      chat_id = 123_456_789
      phone_number = "+1_234_567_890"
      first_name = "John"

      Req.Test.expect(TelegramClientMock, fn request ->
        assert request.method == "POST"
        assert request.request_path == "/bot#{@bot_token}/sendContact"

        {:ok, body, _request} = Plug.Conn.read_body(request)
        decoded_body = Jason.decode!(body)
        assert decoded_body == %{
          "chat_id" => chat_id,
          "phone_number" => phone_number,
          "first_name" => first_name
        }

        request
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "chat" => %{"id" => chat_id},
            "contact" => %{
              "phone_number" => phone_number,
              "first_name" => first_name
            }
          }
        }))
      end)

      result = SendContact.handler(
        %{
          chat_id: chat_id,
          phone_number: phone_number,
          first_name: first_name
        },
        %{name: "TestAgent", plug: {Req.Test, __MODULE__}}
      )

      assert {:ok, %{sent: true, message_id: 42, chat_id: ^chat_id}} = result
    end

    test "sends a contact with all optional parameters" do
      chat_id = 123_456_789
      phone_number = "+1_234_567_890"
      first_name = "John"
      last_name = "Doe"
      vcard = "BEGIN:VCARD\\nVERSION:3.0\\nFN:John Doe\\nTEL:+1_234_567_890\\nEND:VCARD"

      Req.Test.expect(TelegramClientMock, fn request ->
        assert request.method == "POST"
        assert request.request_path == "/bot#{@bot_token}/sendContact"

        {:ok, body, _request} = Plug.Conn.read_body(request)
        decoded_body = Jason.decode!(body)
        assert decoded_body == %{
          "chat_id" => chat_id,
          "phone_number" => phone_number,
          "first_name" => first_name,
          "last_name" => last_name,
          "vcard" => vcard,
          "disable_notification" => true,
          "protect_content" => true,
          "reply_to_message_id" => 123,
          "allow_sending_without_reply" => true,
          "reply_markup" => %{
            "inline_keyboard" => [[%{"text" => "Test", "callback_data" => "test"}]]
          }
        }

        request
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => 42,
            "chat" => %{"id" => chat_id},
            "contact" => %{
              "phone_number" => phone_number,
              "first_name" => first_name,
              "last_name" => last_name,
              "vcard" => vcard
            }
          }
        }))
      end)

      result = SendContact.handler(
        %{
          chat_id: chat_id,
          phone_number: phone_number,
          first_name: first_name,
          last_name: last_name,
          vcard: vcard,
          disable_notification: true,
          protect_content: true,
          reply_to_message_id: 123,
          allow_sending_without_reply: true,
          reply_markup: %{
            inline_keyboard: [[%{text: "Test", callback_data: "test"}]]
          }
        },
        %{name: "TestAgent", plug: {Req.Test, __MODULE__}}
      )

      assert {:ok, %{sent: true, message_id: 42, chat_id: ^chat_id}} = result
    end

    test "validates required parameters" do
      result = SendContact.handler(
        %{},
        %{name: "TestAgent", plug: {Req.Test, __MODULE__}}
      )

      assert {:error, "Missing or invalid chat_id"} = result

      result = SendContact.handler(
        %{chat_id: 123_456_789},
        %{name: "TestAgent", plug: {Req.Test, __MODULE__}}
      )

      assert {:error, "Missing or invalid phone_number"} = result

      result = SendContact.handler(
        %{chat_id: 123_456_789, phone_number: "+1_234_567_890"},
        %{name: "TestAgent", plug: {Req.Test, __MODULE__}}
      )

      assert {:error, "Missing or invalid first_name"} = result
    end

    test "handles API errors" do
      error_description = "Bad Request: contact not found"

      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => error_description
        }))
      end)

      result = SendContact.handler(
        %{
          chat_id: 123_456_789,
          phone_number: "+1_234_567_890",
          first_name: "John"
        },
        %{name: "TestAgent", plug: {Req.Test, __MODULE__}}
      )

      expected_error = "Failed to send contact: #{error_description} (HTTP 400)"
      assert {:error, ^expected_error} = result
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendContact.view()

      assert prism.input_schema.type == :object
      assert prism.input_schema.required == ["chat_id", "phone_number", "first_name"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :phone_number)
      assert Map.has_key?(prism.input_schema.properties, :first_name)
      assert Map.has_key?(prism.input_schema.properties, :last_name)
      assert Map.has_key?(prism.input_schema.properties, :vcard)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
      assert Map.has_key?(prism.input_schema.properties, :protect_content)
      assert Map.has_key?(prism.input_schema.properties, :reply_to_message_id)
      assert Map.has_key?(prism.input_schema.properties, :allow_sending_without_reply)
      assert Map.has_key?(prism.input_schema.properties, :reply_markup)
    end

    test "validates output schema" do
      prism = SendContact.view()

      assert prism.output_schema.type == :object
      assert prism.output_schema.required == ["sent", "message_id"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
    end
  end
end
