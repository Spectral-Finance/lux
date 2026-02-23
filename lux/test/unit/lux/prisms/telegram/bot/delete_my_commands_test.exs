defmodule Lux.Prisms.Telegram.Bot.DeleteMyCommandsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Bot.DeleteMyCommands

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully deletes all commands for default scope" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{success: true, description: description}} =
               DeleteMyCommands.handler(
                 %{plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )

      assert description =~ "deleted"
    end

    test "deletes commands for specific scope" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["scope"]["type"] == "all_private_chats"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, %{success: true, description: desc}} =
               DeleteMyCommands.handler(
                 %{
                   scope: %{type: "all_private_chats"},
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )

      assert desc =~ "all_private_chats"
    end

    test "deletes commands for specific language" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["language_code"] == "en"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, %{success: true}} =
               DeleteMyCommands.handler(
                 %{language_code: "en", plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "handles API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "ok" => false,
          "description" => "Unauthorized"
        }))
      end)

      assert {:error, "Failed to delete commands: " <> _} =
               DeleteMyCommands.handler(
                 %{plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates schema" do
      prism = DeleteMyCommands.view()
      assert Map.has_key?(prism.input_schema.properties, :scope)
      assert Map.has_key?(prism.input_schema.properties, :language_code)
      assert "success" in prism.output_schema.required
    end
  end
end
