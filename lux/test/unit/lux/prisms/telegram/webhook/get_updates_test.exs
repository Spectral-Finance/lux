defmodule Lux.Prisms.Telegram.Webhook.GetUpdatesTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Webhook.GetUpdates

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully retrieves updates" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{
              "update_id" => 123_456,
              "message" => %{
                "message_id" => 1,
                "chat" => %{"id" => 789},
                "text" => "Hello"
              }
            }
          ]
        }))
      end)

      assert {:ok, %{updates: updates}} =
               GetUpdates.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)

      assert length(updates) == 1
      assert hd(updates)["update_id"] == 123_456
    end

    test "retrieves updates with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["offset"] == 123_457
        assert decoded_body["limit"] == 10
        assert decoded_body["timeout"] == 30
        assert decoded_body["allowed_updates"] == ["message"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => []
        }))
      end)

      assert {:ok, %{updates: []}} =
               GetUpdates.handler(
                 %{
                   offset: 123_457,
                   limit: 10,
                   timeout: 30,
                   allowed_updates: ["message"],
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(409, Jason.encode!(%{
          "ok" => false,
          "description" => "Conflict: can't use getUpdates method while webhook is active"
        }))
      end)

      assert {:error, "Failed to get updates: Conflict: can't use getUpdates method while webhook is active (HTTP 409)"} =
               GetUpdates.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = GetUpdates.view()
      assert prism.input_schema.required == []
      assert Map.has_key?(prism.input_schema.properties, :offset)
      assert Map.has_key?(prism.input_schema.properties, :limit)
      assert Map.has_key?(prism.input_schema.properties, :timeout)
      assert Map.has_key?(prism.input_schema.properties, :allowed_updates)
    end

    test "validates output schema" do
      prism = GetUpdates.view()
      assert prism.output_schema.required == ["updates"]
      assert Map.has_key?(prism.output_schema.properties, :updates)
    end
  end
end
