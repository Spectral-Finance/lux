defmodule Lux.Prisms.Telegram.Management.GetMyCommandsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Management.GetMyCommands

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully retrieves bot commands" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{"command" => "start", "description" => "Start the bot"},
            %{"command" => "help", "description" => "Show help"}
          ]
        }))
      end)

      assert {:ok, %{commands: commands}} =
               GetMyCommands.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)

      assert length(commands) == 2
    end

    test "retrieves commands with scope and language_code" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["language_code"] == "en"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => []
        }))
      end)

      assert {:ok, %{commands: []}} =
               GetMyCommands.handler(
                 %{language_code: "en", plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: invalid scope"
        }))
      end)

      assert {:error, "Failed to get commands: Bad Request: invalid scope (HTTP 400)"} =
               GetMyCommands.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = GetMyCommands.view()
      assert prism.input_schema.required == []
      assert Map.has_key?(prism.input_schema.properties, :scope)
      assert Map.has_key?(prism.input_schema.properties, :language_code)
    end

    test "validates output schema" do
      prism = GetMyCommands.view()
      assert prism.output_schema.required == ["commands"]
      assert Map.has_key?(prism.output_schema.properties, :commands)
    end
  end
end
