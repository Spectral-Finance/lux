defmodule Lux.Prisms.Telegram.Management.CloseTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Management.Close

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully closes bot instance" do
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
               Close.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "ok" => false,
          "description" => "Too Many Requests: retry after 10"
        }))
      end)

      assert {:error, "Failed to close bot: Too Many Requests: retry after 10 (HTTP 429)"} =
               Close.handler(%{plug: {Req.Test, __MODULE__}}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = Close.view()
      assert prism.input_schema.required == []
    end

    test "validates output schema" do
      prism = Close.view()
      assert prism.output_schema.required == ["success"]
      assert Map.has_key?(prism.output_schema.properties, :success)
    end
  end
end
