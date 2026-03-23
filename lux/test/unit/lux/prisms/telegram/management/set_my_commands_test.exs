defmodule Lux.Prisms.Telegram.Management.SetMyCommandsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Management.SetMyCommands

  @agent_ctx %{name: "TestAgent"}
  @commands [
    %{command: "start", description: "Start the bot"},
    %{command: "help", description: "Show help"}
  ]

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets bot commands" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert length(decoded_body["commands"]) == 2

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true}} =
               SetMyCommands.handler(
                 %{commands: @commands, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "successfully sets commands with scope and language_code" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["language_code"] == "en"
        assert decoded_body["scope"]["type"] == "all_private_chats"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true}} =
               SetMyCommands.handler(
                 %{
                   commands: @commands,
                   scope: %{type: "all_private_chats"},
                   language_code: "en",
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates required commands parameter" do
      result = SetMyCommands.handler(%{}, @agent_ctx)
      assert result == {:error, "Missing or invalid commands"}
    end

    test "validates commands is non-empty list" do
      result = SetMyCommands.handler(%{commands: []}, @agent_ctx)
      assert result == {:error, "Missing or invalid commands"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: invalid command"
        }))
      end)

      assert {:error, "Failed to set commands: Bad Request: invalid command (HTTP 400)"} =
               SetMyCommands.handler(
                 %{commands: @commands, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SetMyCommands.view()
      assert prism.input_schema.required == ["commands"]
      assert Map.has_key?(prism.input_schema.properties, :commands)
      assert Map.has_key?(prism.input_schema.properties, :scope)
      assert Map.has_key?(prism.input_schema.properties, :language_code)
    end

    test "validates output schema" do
      prism = SetMyCommands.view()
      assert prism.output_schema.required == ["success"]
      assert Map.has_key?(prism.output_schema.properties, :success)
    end
  end
end
