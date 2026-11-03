defmodule Lux.LLM.OllamaTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Ollama
  alias Lux.LLM.Ollama.ModelManager
  alias Lux.LLM.Ollama.ResourceMonitor
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  require Lux.Beam
  require Lux.Lens
  require Lux.Prism

  defmodule LocalTestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Local Test Prism",
      input_schema: %{type: :object, properties: %{command: %{type: :string}}},
      description: "A local test prism"

    def handler(%{"command" => "ping"}, _context), do: {:ok, %{reply: "pong"}}
    def handler(%{"command" => "fail"}, _context), do: {:error, "failed"}
  end

  defmodule LocalTestBeam do
    @moduledoc false
    use Lux.Beam,
      name: "Local Test Beam",
      input_schema: %{type: :object, properties: %{command: %{type: :string}}},
      description: "A local test beam"

    sequence do
      step(:cmd, LocalTestPrism, %{})
    end
  end

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "tool_to_function/1" do
    test "converts Beam to Ollama function" do
      beam =
        Lux.Beam.new(
          name: "SystemScan",
          description: "Scans local ports",
          input_schema: %{
            type: "object",
            properties: %{"target" => %{type: "string"}}
          }
        )

      func = Ollama.tool_to_function(beam)
      assert func.type == "function"
      assert func.function.name == "SystemScan"
    end

    test "converts Prism to Ollama function" do
      prism = LocalTestPrism.view()
      func = Ollama.tool_to_function(prism)
      assert func.type == "function"
      assert func.function.name == "Lux_LLM_OllamaTest_LocalTestPrism"
    end
  end

  describe "call/3" do
    test "makes local API call to Ollama and calculates performance metrics" do
      Req.Test.stub(Ollama, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)

        assert json["model"] == "llama3.2"
        assert json["options"]["num_ctx"] == 4096
        assert json["messages"] == [%{"role" => "user", "content" => "Hello local model"}]

        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "created_at" => "2026-06-01T12:00:00Z",
          "message" => %{
            "role" => "assistant",
            "content" => "Hello from local Ollama!"
          },
          "done" => true,
          "done_reason" => "stop",
          "total_duration" => 200_000_000,        # 200ms
          "load_duration" => 20_000_000,          # 20ms
          "prompt_eval_count" => 10,
          "prompt_eval_duration" => 40_000_000,   # 40ms -> 250 tps
          "eval_count" => 25,
          "eval_duration" => 120_000_000          # 120ms -> 208.33 tps
        })
      end)

      config = %{
        model: "llama3.2",
        temperature: 0.5,
        num_ctx: 4096
      }

      assert {:ok, %Signal{} = signal} = Ollama.call("Hello local model", [], config)
      assert signal.schema_id == ResponseSignal
      assert signal.payload.content == "Hello from local Ollama!"
      assert signal.payload.model == "llama3.2"

      metrics = signal.metadata.metrics
      assert metrics.total_duration_ms == 200.0
      assert metrics.prompt_tokens == 10
      assert metrics.eval_tokens == 25
      assert metrics.prompt_tokens_per_sec == 250.0
      assert metrics.eval_tokens_per_sec == 208.33
    end

    test "handles local tool calls execution" do
      Req.Test.stub(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{
            "role" => "assistant",
            "content" => nil,
            "tool_calls" => [
              %{
                "function" => %{
                  "name" => "Lux_LLM_OllamaTest_LocalTestPrism",
                  "arguments" => %{"command" => "ping"}
                }
              }
            ]
          },
          "done" => true
        })
      end)

      assert {:ok, %Signal{} = signal} =
               Ollama.call("Send ping", [LocalTestPrism], %{model: "llama3.2"})

      assert signal.payload.tool_calls_results == [%{reply: "pong"}]
    end

    test "handles model not found (404)" do
      Req.Test.stub(Ollama, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"error" => "model 'unknown:latest' not found"})
      end)

      assert {:error, {:model_not_found, _}} =
               Ollama.call("Hi", [], %{model: "unknown"})
    end
  end

  describe "Preload & Unload" do
    test "preloads and unloads models via keep_alive" do
      Req.Test.stub(Ollama, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)

        assert json["model"] == "llama3.2"
        Req.Test.json(conn, %{"status" => "success"})
      end)

      assert {:ok, :preloaded} =
               Ollama.preload_model("llama3.2", "15m", plug: {Req.Test, Ollama})

      assert {:ok, :preloaded} =
               Ollama.unload_model("llama3.2", plug: {Req.Test, Ollama})
    end
  end

  describe "ModelManager" do
    test "lists local models" do
      Req.Test.stub(ModelManager, fn conn ->
        Req.Test.json(conn, %{
          "models" => [
            %{
              "name" => "llama3.2:latest",
              "model" => "llama3.2:latest",
              "size" => 2_000_000_000,
              "digest" => "abc123",
              "details" => %{
                "family" => "llama",
                "parameter_size" => "3.2B",
                "quantization_level" => "Q4_K_M"
              }
            }
          ]
        })
      end)

      assert {:ok, [model | _]} = ModelManager.list_models(plug: {Req.Test, ModelManager})
      assert model.name == "llama3.2:latest"
      assert model.family == "llama"
      assert model.parameter_size == "3.2B"
    end

    test "lists running models in VRAM via /api/ps" do
      Req.Test.stub(ModelManager, fn conn ->
        Req.Test.json(conn, %{
          "models" => [
            %{
              "name" => "llama3.2:latest",
              "size_vram" => 1_500_000_000
            }
          ]
        })
      end)

      assert {:ok, [running | _]} = ModelManager.list_running_models(plug: {Req.Test, ModelManager})
      assert running.name == "llama3.2:latest"
      assert running.size_vram == 1_500_000_000
    end
  end

  describe "ResourceMonitor" do
    test "calculates metrics accurately" do
      data = %{
        "total_duration" => 100_000_000,
        "load_duration" => 10_000_000,
        "prompt_eval_duration" => 20_000_000,
        "eval_duration" => 70_000_000,
        "prompt_eval_count" => 10,
        "eval_count" => 35
      }

      metrics = ResourceMonitor.parse_metrics(data)
      assert metrics.total_duration_ms == 100.0
      assert metrics.load_duration_ms == 10.0
      assert metrics.prompt_eval_duration_ms == 20.0
      assert metrics.eval_duration_ms == 70.0
      assert metrics.prompt_tokens == 10
      assert metrics.eval_tokens == 35
      assert metrics.eval_tokens_per_sec == 500.0
    end
  end
end
