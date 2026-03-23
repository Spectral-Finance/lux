defmodule Lux.Prisms.Telegram.Management.DeleteMyCommandsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Management.DeleteMyCommands

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully deletes bot commands" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true}} =
               DeleteMyCommands.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end

    test "deletes commands with scope and language_code" do
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
               DeleteMyCommands.handler(
                 %{
                   scope: %{type: "all_private_chats"},
                   language_code: "en",
                   plug: {Req.Test, __MODULE__}
                 },
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

      assert {:error, "Failed to delete commands: Bad Request: invalid scope (HTTP 400)"} =
               DeleteMyCommands.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = DeleteMyCommands.view()
      assert prism.input_schema.required == []
      assert Map.has_key?(prism.input_schema.properties, :scope)
      assert Map.has_key?(prism.input_schema.properties, :language_code)
    end

    test "validates output schema" do
      prism = DeleteMyCommands.view()
      assert prism.output_schema.required == ["success"]
      assert Map.has_key?(prism.output_schema.properties, :success)
    end
  end
end
