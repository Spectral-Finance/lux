defmodule Lux.Prisms.Telegram.Messages.CopyMessagesTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.CopyMessages

  @chat_id 123_456_789
  @from_chat_id 987_654_321
  @message_ids [42, 43, 44]
  @new_message_ids [123, 124, 125]
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully copies multiple messages with required parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["from_chat_id"] == @from_chat_id
        assert decoded_body["message_ids"] == @message_ids

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => Enum.map(@new_message_ids, fn id -> %{"message_id" => id} end)
        }))
      end)

      assert {:ok,
              %{copied: true, message_ids: @new_message_ids, from_chat_id: @from_chat_id, chat_id: @chat_id}} =
               CopyMessages.handler(
                 %{
                   chat_id: @chat_id,
                   from_chat_id: @from_chat_id,
                   message_ids: @message_ids,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully copies multiple messages with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["from_chat_id"] == @from_chat_id
        assert decoded_body["message_ids"] == @message_ids
        assert decoded_body["disable_notification"] == true
        assert decoded_body["protect_content"] == true
        assert decoded_body["remove_caption"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => Enum.map(@new_message_ids, fn id -> %{"message_id" => id} end)
        }))
      end)

      assert {:ok,
              %{copied: true, message_ids: @new_message_ids, from_chat_id: @from_chat_id, chat_id: @chat_id}} =
               CopyMessages.handler(
                 %{
                   chat_id: @chat_id,
                   from_chat_id: @from_chat_id,
                   message_ids: @message_ids,
                   disable_notification: true,
                   protect_content: true,
                   remove_caption: true,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates required parameters" do
      result = CopyMessages.handler(%{from_chat_id: @from_chat_id, message_ids: @message_ids}, @agent_ctx)
      assert result == {:error, "Missing or invalid chat_id"}

      result = CopyMessages.handler(%{chat_id: @chat_id, message_ids: @message_ids}, @agent_ctx)
      assert result == {:error, "Missing or invalid from_chat_id"}

      result = CopyMessages.handler(%{chat_id: @chat_id, from_chat_id: @from_chat_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid message_ids"}
    end

    test "validates message_ids format" do
      # Empty message_ids
      result = CopyMessages.handler(
        %{chat_id: @chat_id, from_chat_id: @from_chat_id, message_ids: []},
        @agent_ctx
      )
      assert result == {:error, "message_ids must contain between 1 and 100 items"}

      # Too many message_ids
      large_list = Enum.to_list(1..101)
      result = CopyMessages.handler(
        %{chat_id: @chat_id, from_chat_id: @from_chat_id, message_ids: large_list},
        @agent_ctx
      )
      assert result == {:error, "message_ids must contain between 1 and 100 items"}

      # Non-integer message_ids
      result = CopyMessages.handler(
        %{chat_id: @chat_id, from_chat_id: @from_chat_id, message_ids: [1, "2", 3]},
        @agent_ctx
      )
      assert result == {:error, "All message_ids must be integers"}

      # Non-increasing order
      result = CopyMessages.handler(
        %{chat_id: @chat_id, from_chat_id: @from_chat_id, message_ids: [3, 1, 2]},
        @agent_ctx
      )
      assert result == {:error, "message_ids must be specified in a strictly increasing order"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: messages to copy not found"
        }))
      end)

      assert {:error, "Failed to copy messages: Bad Request: messages to copy not found (HTTP 400)"} =
               CopyMessages.handler(
                 %{
                   chat_id: @chat_id,
                   from_chat_id: @from_chat_id,
                   message_ids: @message_ids,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = CopyMessages.view()
      assert prism.input_schema.required == ["chat_id", "from_chat_id", "message_ids"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :from_chat_id)
      assert Map.has_key?(prism.input_schema.properties, :message_ids)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
      assert Map.has_key?(prism.input_schema.properties, :protect_content)
      assert Map.has_key?(prism.input_schema.properties, :remove_caption)
    end

    test "validates output schema" do
      prism = CopyMessages.view()
      assert prism.output_schema.required == ["copied", "message_ids"]
      assert Map.has_key?(prism.output_schema.properties, :copied)
      assert Map.has_key?(prism.output_schema.properties, :message_ids)
      assert Map.has_key?(prism.output_schema.properties, :from_chat_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
    end
  end
end
