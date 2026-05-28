defmodule Lux.LLM.OpenRouterTest do
  use UnitAPICase, async: true

  alias Lux.LLM.OpenRouter
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  require Lux.Prism

  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Test Prism",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}},
      description: "A test prism"

    def handler(%{"value" => "success"}, _context), do: {:ok, %{result: "success test"}}
  end

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "call/3" do
    test "makes correct API call with auth and routing headers" do
      config = %{
        api_key: "test_openrouter_key",
        model: "openai/gpt-4o"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v1/chat/completions"

        auth = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_openrouter_key"] = auth

        referer = Plug.Conn.get_req_header(conn, "http-referer")
        assert [_] = referer

        title = Plug.Conn.get_req_header(conn, "x-title")
        assert ["Lux"] = title

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "openai/gpt-4o"
        assert decoded["response_format"]["type"] == "json_object"

        Req.Test.json(conn, %{
          "id" => "gen-1",
          "model" => "openai/gpt-4o",
          "created" => 1_700_000_000,
          "choices" => [
            %{
              "message" => %{"content" => ~s({"result": "ok"}), "tool_calls" => nil},
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 5}
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"result" => "ok"},
                  finish_reason: "stop",
                  model: "openai/gpt-4o"
                }
              }} = OpenRouter.call("test prompt", [], config)
    end

    test "handles 401 invalid api key" do
      config = %{api_key: "bad_key", model: "openai/gpt-4o"}

      Req.Test.expect(OpenRouter, fn conn ->
        Plug.Conn.send_resp(conn, 401, Jason.encode!(%{"error" => %{"message" => "Invalid key"}}))
      end)

      assert {:error, :invalid_api_key} = OpenRouter.call("prompt", [], config)
    end

    test "handles 429 rate limit" do
      config = %{api_key: "key", model: "openai/gpt-4o"}

      Req.Test.expect(OpenRouter, fn conn ->
        Plug.Conn.send_resp(conn, 429, Jason.encode!(%{"error" => %{"message" => "Rate limited"}}))
      end)

      assert {:error, :rate_limited} = OpenRouter.call("prompt", [], config)
    end

    test "handles tool calls" do
      config = %{api_key: "test_key", model: "anthropic/claude-3-5-sonnet", json_response: false}

      Req.Test.expect(OpenRouter, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert [_tool] = decoded["tools"]
        assert decoded["tool_choice"] == "auto"

        Req.Test.json(conn, %{
          "id" => "gen-2",
          "model" => "anthropic/claude-3-5-sonnet",
          "created" => 1_700_000_000,
          "choices" => [
            %{
              "message" => %{
                "content" => nil,
                "tool_calls" => [
                  %{
                    "type" => "function",
                    "function" => %{
                      "name" => "#{TestPrism}",
                      "arguments" => ~s({"value": "success"})
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ],
          "usage" => %{}
        })
      end)

      assert {:ok, %Signal{payload: %{finish_reason: "tool_calls"}}} =
               OpenRouter.call("prompt", [TestPrism], config)
    end

    test "custom site_url and site_name are passed as headers" do
      config = %{
        api_key: "key",
        model: "openai/gpt-4o",
        site_url: "https://myapp.com",
        site_name: "My App"
      }

      Req.Test.expect(OpenRouter, fn conn ->
        assert ["https://myapp.com"] = Plug.Conn.get_req_header(conn, "http-referer")
        assert ["My App"] = Plug.Conn.get_req_header(conn, "x-title")

        Req.Test.json(conn, %{
          "model" => "openai/gpt-4o",
          "choices" => [%{"message" => %{"content" => "{}", "tool_calls" => nil}, "finish_reason" => "stop"}],
          "usage" => %{}
        })
      end)

      assert {:ok, _} = OpenRouter.call("prompt", [], config)
    end
  end

  describe "tool_to_function/1" do
    test "converts a prism to a function spec" do
      function = OpenRouter.tool_to_function(TestPrism)

      assert %{
               type: "function",
               function: %{description: "A test prism"}
             } = function
    end
  end
end
