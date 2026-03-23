defmodule Lux.Prisms.Telegram.Management.GetMeTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Management.GetMe

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully retrieves bot info" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "id" => 123_456_789,
            "is_bot" => true,
            "first_name" => "TestBot",
            "username" => "test_bot",
            "can_join_groups" => true,
            "can_read_all_group_messages" => false,
            "supports_inline_queries" => false
          }
        }))
      end)

      assert {:ok, %{
        id: 123_456_789,
        is_bot: true,
        first_name: "TestBot",
        username: "test_bot",
        can_join_groups: true,
        can_read_all_group_messages: false,
        supports_inline_queries: false
      }} = GetMe.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "ok" => false,
          "description" => "Unauthorized"
        }))
      end)

      assert {:error, "Failed to get bot info: :invalid_token"} =
               GetMe.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = GetMe.view()
      assert prism.input_schema.required == []
    end

    test "validates output schema" do
      prism = GetMe.view()
      assert prism.output_schema.required == ["id", "is_bot", "first_name"]
      assert Map.has_key?(prism.output_schema.properties, :id)
      assert Map.has_key?(prism.output_schema.properties, :is_bot)
      assert Map.has_key?(prism.output_schema.properties, :first_name)
      assert Map.has_key?(prism.output_schema.properties, :username)
    end
  end
end
