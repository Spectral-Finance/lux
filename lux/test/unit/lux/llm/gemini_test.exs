defmodule Lux.LLM.GeminiTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Gemini
  alias Lux.LLM.ResponseSignal

  require Lux.Beam
  require Lux.Lens
  require Lux.Prism

  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Test Prism",
      input_schema: %{type: :object, properties: %{location: %{type: :string}}},
      description: "A test prism"

    def handler(%{"location" => loc}, _context), do: {:ok, %{weather: "sunny in #{loc}"}}
  end

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "provider behaviour metadata" do
    test "id/0 returns :gemini" do
      assert Gemini.id() == :gemini
    end

    test "models/0 returns Gemini ModelConfig structs" do
      models = Gemini.models()
      assert length(models) >= 2
      assert Enum.any?(models, &(&1.id == "gemini-1.5-flash"))
      assert Enum.any?(models, &(&1.id == "gemini-1.5-pro"))
    end
  end

  describe "call/3" do
    test "formats prompt and parses successful Gemini response into ResponseSignal" do
      Req.Test.stub(Gemini, fn conn ->
        assert conn.request_path == "/v1beta/models/gemini-1.5-flash:generateContent"
        assert conn.query_string =~ "key=test-gemini-key"

        {:ok, body, _} = Plug.Conn.read_body(conn)
        json_body = Jason.decode!(body)

        assert %{"contents" => [%{"parts" => [%{"text" => "Hello Gemini"}]}]} = json_body

        resp_payload = %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => "Hello from Gemini!"}],
                "role" => "model"
              },
              "finishReason" => "STOP"
            }
          ],
          "usageMetadata" => %{
            "promptTokenCount" => 10,
            "candidatesTokenCount" => 20,
            "totalTokenCount" => 30
          }
        }

        Plug.Conn.send_resp(conn, 200, Jason.encode!(resp_payload))
      end)

      assert {:ok, signal} =
               Gemini.call("Hello Gemini", [],
                 api_key: "test-gemini-key",
                 model: "gemini-1.5-flash",
                 plug: {Req.Test, Gemini}
               )

      assert signal.schema_id == ResponseSignal
      assert signal.payload.content == %{"text" => "Hello from Gemini!"}
      assert signal.payload.finish_reason == "STOP"
      assert signal.metadata.provider == :gemini
      assert signal.metadata.usage["total_tokens"] == 30
    end

    test "handles 401 invalid API key error" do
      Req.Test.stub(Gemini, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => "unauthorized"}))
      end)

      assert {:error, :invalid_api_key} =
               Gemini.call("Hello", [],
                 api_key: "bad-key",
                 plug: {Req.Test, Gemini}
               )
    end
  end

  describe "tool_to_function/1" do
    test "converts Prism tool to Gemini function declaration" do
      func_decl = Gemini.tool_to_function(TestPrism)

      assert func_decl.name == "Lux_LLM_GeminiTest_TestPrism"
      assert func_decl.description == "A test prism"
      assert is_map(func_decl.parameters)
    end
  end
end
