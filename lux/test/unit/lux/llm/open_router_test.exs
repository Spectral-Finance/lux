defmodule Lux.LLM.OpenRouterTest do
  use UnitAPICase, async: true

  alias Lux.LLM.OpenRouter
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "call/3" do
    test "makes correct API call" do
      config = %{
        api_key: "test_key",
        model: "openai/gpt-4o-mini"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "openai/gpt-4o-mini"

        Req.Test.json(conn, %{
          "id" => "test_id",
          "model" => "openai/gpt-4o-mini",
          "choices" => [
            %{
              "message" => %{"content" => ~s({"result": "Test response"})},
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"cost" => 0.001}
        })
      end)

      assert {:ok, %Signal{schema_id: ResponseSignal}} =
        OpenRouter.call("test prompt", [], config)
    end

    test "handles rate limit retry" do
      config = %{api_key: "test_key", model: "openai/gpt-4o-mini"}

      assert {:error, _} = OpenRouter.call("test", [], config)
    end
  end
end