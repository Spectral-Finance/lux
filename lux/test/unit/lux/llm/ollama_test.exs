defmodule Lux.LLM.OllamaTest do
  use UnitCase, async: false

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.Ollama
  alias Lux.LLM.Ollama.Config
  alias Lux.LLM.Ollama.ModelManager
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism
  alias Lux.Signal

  setup do
    ModelManager.clear_cache()
    :ok
  end

  describe "call/3 chat completion" do
    test "formats request body with options and returns ResponseSignal" do
      Req.Test.stub(Lux.LLM.Ollama, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "llama3.2"
        assert decoded["stream"] == false
        assert decoded["options"]["temperature"] == 0.2
        assert decoded["options"]["num_ctx"] == 8192
        assert decoded["options"]["num_gpu"] == 1
        assert decoded["options"]["num_thread"] == 8
        assert List.last(decoded["messages"]) == %{"role" => "user", "content" => "Hello Ollama"}

        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "created_at" => "2026-11-11T00:00:00Z",
          "message" => %{
            "role" => "assistant",
            "content" => "{\"greeting\": \"Hello back!\"}"
          },
          "done" => true,
          "done_reason" => "stop",
          "total_duration" => 500_000_000,
          "load_duration" => 50_000_000,
          "prompt_eval_count" => 12,
          "eval_count" => 25,
          "eval_duration" => 250_000_000
        })
      end)

      Application.put_env(:lux, Lux.LLM.Ollama, plug: {Req.Test, Lux.LLM.Ollama})

      config = %Config{
        model: "llama3.2",
        temperature: 0.2,
        num_ctx: 8192,
        num_gpu: 1,
        num_thread: 8,
        json_response: true
      }

      assert {:ok, %Signal{schema_id: ResponseSignal, payload: payload, metadata: metadata}} =
               Ollama.call("Hello Ollama", [], config)

      assert payload.content == %{"greeting" => "Hello back!"}
      assert payload.model == "llama3.2"
      assert payload.finish_reason == "stop"
      assert payload.usage == %{prompt_tokens: 12, completion_tokens: 25, total_tokens: 37}
      assert metadata.provider == :ollama
      assert metadata.tokens_per_second == 100.0

      metrics = ModelManager.get_metrics("llama3.2")
      assert metrics.calls == 1
      assert metrics.total_tokens == 37
    end

    test "converts Beam, Prism, and Lens tools and normalizes tool_calls" do
      beam = %Beam{
        name: "Calculator Beam",
        description: "Evaluates arithmetic",
        input_schema: %{type: "object", properties: %{expr: %{type: "string"}}}
      }

      prism = %Prism{
        name: "Swap Prism",
        description: "Executes token swap",
        input_schema: %{type: "object", properties: %{token: %{type: "string"}}}
      }

      lens = %Lens{
        name: "Price Lens",
        description: "Reads price feed",
        schema: %{type: "object", properties: %{symbol: %{type: "string"}}}
      }

      Req.Test.stub(Lux.LLM.Ollama, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert length(decoded["tools"]) == 3

        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{
            "role" => "assistant",
            "content" => "",
            "tool_calls" => [
              %{
                "function" => %{
                  "name" => "Calculator_Beam",
                  "arguments" => %{"expr" => "2 + 2"}
                }
              }
            ]
          },
          "done" => true
        })
      end)

      Application.put_env(:lux, Lux.LLM.Ollama, plug: {Req.Test, Lux.LLM.Ollama})

      assert {:ok, %Signal{payload: payload}} =
               Ollama.call("Compute 2 + 2", [beam, prism, lens], %{model: "llama3.2"})

      assert payload.finish_reason == "tool_calls"
      assert [
               %{
                 "type" => "function",
                 "function" => %{
                   "name" => "Calculator_Beam",
                   "arguments" => %{"expr" => "2 + 2"}
                 }
               }
             ] = payload.tool_calls
    end
  end

  describe "embeddings/2" do
    test "returns vector embeddings from /api/embeddings" do
      Req.Test.stub(Lux.LLM.Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "nomic-embed-text",
          "embedding" => [0.12, -0.34, 0.56],
          "total_duration" => 10_000_000
        })
      end)

      Application.put_env(:lux, Lux.LLM.Ollama, plug: {Req.Test, Lux.LLM.Ollama})

      assert {:ok, %{embeddings: [0.12, -0.34, 0.56], model: "nomic-embed-text"}} =
               Ollama.embeddings("hello world", %{model: "nomic-embed-text"})
    end
  end
end
