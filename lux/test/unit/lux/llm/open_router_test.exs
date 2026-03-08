defmodule Lux.LLM.OpenRouterTest do
  use UnitAPICase, async: true

  alias Lux.LLM.OpenRouter
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  require Lux.Beam
  require Lux.Lens
  require Lux.Prism

  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Test Prism",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}},
      description: "A test prism"

    def handler(%{"value" => "success"}, _context), do: {:ok, %{result: "success test"}}
    def handler(%{"value" => "failure"}, _context), do: {:error, "failure test"}
  end

  defmodule TestBeam do
    @moduledoc false
    use Lux.Beam,
      name: "Test Beam",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}},
      description: "A test beam"

    sequence do
      step(:test, TestPrism, %{})
    end
  end

  defmodule TestLens do
    @moduledoc false
    use Lux.Lens,
      name: "WeatherAPI",
      description: "Gets weather data",
      schema: %{
        type: "object",
        properties: %{
          location: %{type: "string", description: "City name"},
          units: %{type: "string", description: "Temperature units"}
        }
      }
  end

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "call/3" do
    test "sends a basic prompt and returns a valid signal" do
      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "anthropic/claude-sonnet-4-20250514"
        assert is_list(decoded["messages"])
        assert List.last(decoded["messages"])["role"] == "user"
        assert List.last(decoded["messages"])["content"] =~ "Hello"

        Req.Test.json(conn, %{
          "id" => "gen-abc123",
          "choices" => [
            %{
              "message" => %{
                "role" => "assistant",
                "content" => Jason.encode!(%{"response" => "Hello! How can I help you?"})
              },
              "finish_reason" => "stop"
            }
          ],
          "model" => "anthropic/claude-sonnet-4-20250514",
          "usage" => %{
            "prompt_tokens" => 10,
            "completion_tokens" => 15,
            "total_tokens" => 25
          },
          "provider" => "Anthropic"
        })
      end)

      assert {:ok, %Signal{} = signal} =
               OpenRouter.call("Hello", [], %{
                 model: "anthropic/claude-sonnet-4-20250514",
                 api_key: "test-key",
               })

      assert signal.schema_id == ResponseSignal
      assert signal.payload.content == %{"response" => "Hello! How can I help you?"}
      assert signal.payload.model == "anthropic/claude-sonnet-4-20250514"
      assert signal.payload.finish_reason == "stop"
      assert signal.metadata.provider_name == "Anthropic"
    end

    test "sends tools in the request" do
      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert is_list(decoded["tools"])
        assert length(decoded["tools"]) == 1
        assert hd(decoded["tools"])["type"] == "function"

        Req.Test.json(conn, %{
          "id" => "gen-tools123",
          "choices" => [
            %{
              "message" => %{
                "role" => "assistant",
                "content" => Jason.encode!(%{"result" => "tool response"}),
                "tool_calls" => nil
              },
              "finish_reason" => "stop"
            }
          ],
          "model" => "openai/gpt-4",
          "usage" => %{"prompt_tokens" => 20, "completion_tokens" => 10, "total_tokens" => 30}
        })
      end)

      assert {:ok, %Signal{}} =
               OpenRouter.call("Use the test prism", [TestPrism], %{
                 model: "openai/gpt-4",
                 api_key: "test-key",
               })
    end

    test "includes provider preferences in request body" do
      provider_config = %{
        order: ["Anthropic", "OpenAI"],
        allow_fallbacks: true,
        require_parameters: true
      }

      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["provider"]["order"] == ["Anthropic", "OpenAI"]
        assert decoded["provider"]["allow_fallbacks"] == true

        Req.Test.json(conn, %{
          "id" => "gen-prov123",
          "choices" => [
            %{
              "message" => %{"role" => "assistant", "content" => Jason.encode!(%{"ok" => true})},
              "finish_reason" => "stop"
            }
          ],
          "model" => "anthropic/claude-sonnet-4-20250514",
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 5, "total_tokens" => 10}
        })
      end)

      assert {:ok, %Signal{}} =
               OpenRouter.call("test", [], %{
                 model: "anthropic/claude-sonnet-4-20250514",
                 api_key: "test-key",
                 provider: provider_config,
               })
    end

    test "includes site headers when configured" do
      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        referer = Plug.Conn.get_req_header(conn, "http-referer")
        title = Plug.Conn.get_req_header(conn, "x-title")

        assert referer == ["https://myapp.com"]
        assert title == ["My App"]

        Req.Test.json(conn, %{
          "id" => "gen-site123",
          "choices" => [
            %{
              "message" => %{"role" => "assistant", "content" => Jason.encode!(%{"ok" => true})},
              "finish_reason" => "stop"
            }
          ],
          "model" => "openai/gpt-4",
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 5, "total_tokens" => 10}
        })
      end)

      assert {:ok, %Signal{}} =
               OpenRouter.call("test", [], %{
                 model: "openai/gpt-4",
                 api_key: "test-key",
                 site_url: "https://myapp.com",
                 site_name: "My App",
               })
    end

    test "handles non-JSON content gracefully" do
      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "id" => "gen-plain123",
          "choices" => [
            %{
              "message" => %{"role" => "assistant", "content" => Jason.encode!(%{"text" => "Just plain text response"})},
              "finish_reason" => "stop"
            }
          ],
          "model" => "meta-llama/llama-3-70b",
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 10, "total_tokens" => 15}
        })
      end)

      assert {:ok, %Signal{} = signal} =
               OpenRouter.call("test", [], %{
                 model: "meta-llama/llama-3-70b",
                 api_key: "test-key",
               })

      assert signal.payload.content == %{"text" => "Just plain text response"}
    end

    test "returns error for invalid API key" do
      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      assert {:error, :invalid_api_key} =
               OpenRouter.call("test", [], %{
                 api_key: "invalid-key",
               })
    end

    test "returns error for insufficient credits" do
      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_status(402)
        |> Req.Test.json(%{"error" => %{"message" => "Insufficient credits"}})
      end)

      assert {:error, :insufficient_credits} =
               OpenRouter.call("test", [], %{
                 api_key: "test-key",
               })
    end

    test "handles API error responses" do
      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid request"}})
      end)

      assert {:error, {400, "Invalid request"}} =
               OpenRouter.call("test", [], %{
                 api_key: "test-key",
               })
    end

    test "includes cost metadata when available" do
      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "id" => "gen-cost123",
          "choices" => [
            %{
              "message" => %{"role" => "assistant", "content" => Jason.encode!(%{"ok" => true})},
              "finish_reason" => "stop"
            }
          ],
          "model" => "openai/gpt-4",
          "usage" => %{
            "prompt_tokens" => 10,
            "completion_tokens" => 20,
            "total_tokens" => 30,
            "cost" => 0.00009
          }
        })
      end)

      assert {:ok, %Signal{} = signal} =
               OpenRouter.call("test", [], %{
                 api_key: "test-key",
               })

      assert signal.metadata.cost == 0.00009
    end

    test "supports transforms parameter" do
      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["transforms"] == ["middle-out"]

        Req.Test.json(conn, %{
          "id" => "gen-transform",
          "choices" => [
            %{
              "message" => %{"role" => "assistant", "content" => Jason.encode!(%{"ok" => true})},
              "finish_reason" => "stop"
            }
          ],
          "model" => "openai/gpt-4",
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 5, "total_tokens" => 10}
        })
      end)

      assert {:ok, %Signal{}} =
               OpenRouter.call("test", [], %{
                 api_key: "test-key",
                 transforms: ["middle-out"],
               })
    end

    test "supports route parameter" do
      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["route"] == "fallback"

        Req.Test.json(conn, %{
          "id" => "gen-route",
          "choices" => [
            %{
              "message" => %{"role" => "assistant", "content" => Jason.encode!(%{"ok" => true})},
              "finish_reason" => "stop"
            }
          ],
          "model" => "openai/gpt-4",
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 5, "total_tokens" => 10}
        })
      end)

      assert {:ok, %Signal{}} =
               OpenRouter.call("test", [], %{
                 api_key: "test-key",
                 route: "fallback",
               })
    end
  end

  describe "list_models/1" do
    test "returns list of available models" do
      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        assert conn.method == "GET"

        Req.Test.json(conn, %{
          "data" => [
            %{
              "id" => "openai/gpt-4",
              "name" => "GPT-4",
              "pricing" => %{"prompt" => "0.03", "completion" => "0.06"},
              "context_length" => 8192
            },
            %{
              "id" => "anthropic/claude-sonnet-4-20250514",
              "name" => "Claude 3.5 Sonnet",
              "pricing" => %{"prompt" => "0.003", "completion" => "0.015"},
              "context_length" => 200_000
            }
          ]
        })
      end)

      assert {:ok, models} =
               OpenRouter.list_models()

      assert length(models) == 2
      assert hd(models)["id"] == "openai/gpt-4"
    end
  end

  describe "get_generation_stats/2" do
    test "returns generation cost data" do
      Req.Test.expect(Lux.LLM.OpenRouter, fn conn ->
        assert conn.method == "GET"

        Req.Test.json(conn, %{
          "data" => %{
            "id" => "gen-abc123",
            "total_cost" => 0.00012,
            "tokens_prompt" => 50,
            "tokens_completion" => 100,
            "model" => "openai/gpt-4"
          }
        })
      end)

      assert {:ok, stats} =
               OpenRouter.get_generation_stats("gen-abc123",
                 api_key: "test-key",
               )

      assert stats["data"]["total_cost"] == 0.00012
    end
  end
end
