defmodule Lux.Prisms.Telegram.Bot.SetMyCommandsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Bot.SetMyCommands

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets commands" do
      commands = [
        %{command: "start", description: "Start the bot"},
        %{command: "help", description: "Show help"}
      ]

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert length(decoded["commands"]) == 2
        assert Enum.at(decoded["commands"], 0)["command"] == "start"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true, command_count: 2}} =
               SetMyCommands.handler(
                 %{commands: commands, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "sets commands with language scope" do
      commands = [%{command: "start", description: "Iniciar"}]

      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["language_code"] == "es"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, %{success: true, command_count: 1}} =
               SetMyCommands.handler(
                 %{commands: commands, language_code: "es", plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "returns error when commands is missing" do
      assert {:error, "commands is required"} = SetMyCommands.handler(%{}, @agent_ctx)
    end

    test "returns error when commands is empty" do
      assert {:error, "commands cannot be empty" <> _} =
               SetMyCommands.handler(%{commands: []}, @agent_ctx)
    end

    test "returns error when more than 100 commands" do
      commands = for i <- 1..101, do: %{command: "cmd#{i}", description: "Command #{i}"}

      assert {:error, "Cannot set more than 100 commands"} =
               SetMyCommands.handler(%{commands: commands}, @agent_ctx)
    end

    test "handles API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: command description must be non-empty"
        }))
      end)

      assert {:error, "Failed to set commands: " <> _} =
               SetMyCommands.handler(
                 %{
                   commands: [%{command: "start", description: ""}],
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SetMyCommands.view()
      assert "commands" in prism.input_schema.required
      assert Map.has_key?(prism.input_schema.properties, :commands)
      assert Map.has_key?(prism.input_schema.properties, :scope)
      assert Map.has_key?(prism.input_schema.properties, :language_code)
    end

    test "validates output schema" do
      prism = SetMyCommands.view()
      assert "success" in prism.output_schema.required
      assert Map.has_key?(prism.output_schema.properties, :command_count)
    end
  end
end
