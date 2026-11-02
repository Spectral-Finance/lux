defmodule Lux.LLM.OllamaTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Ollama
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  require Lux.Beam
  require Lux.Lens
  require Lux.Prism

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "call/3" do
    test "executes chat completion against local daemon" do
      Req.Test.stub(Lux.LLM.Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "llama3.2"
        assert decoded["stream"] == false
        assert decoded["options"]["temperature"] == 0.7
        assert decoded["options"]["num_ctx"] == 4096
        assert decoded["keep_alive"] == "5m"

        response = %{
          "model" => "llama3.2",
          "created_at" => "2026-11-02T11:20:00Z",
          "message" => %{
            "role" => "assistant",
            "content" => "Hello from local Ollama model!",
            "tool_calls" => nil
          },
          "done" => true,
          "total_duration" => 450_000_000,
          "load_duration" => 50_000_000,
          "prompt_eval_count" => 12,
          "eval_count" => 18
        }

        Plug.Conn.resp(conn, 200, Jason.encode!(response))
      end)

      config = %{
        endpoint: "http://localhost:11434",
        model: "llama3.2",
        temperature: 0.7,
        num_ctx: 4096,
        keep_alive: "5m"
      }

      assert {:ok, %Signal{} = signal} = Ollama.call("Hello", [], config)
      assert signal.payload.content == "Hello from local Ollama model!"
      assert signal.payload.model == "llama3.2"
      assert signal.metadata.eval_count == 18
    end

    test "handles 404 model not found" do
      Req.Test.stub(Lux.LLM.Ollama, fn conn ->
        Plug.Conn.resp(conn, 404, Jason.encode!(%{"error" => "model 'nonexistent' not found, try pulling it first"}))
      end)

      config = %{
        endpoint: "http://localhost:11434",
        model: "nonexistent"
      }

      assert {:error, {:model_not_found, message}} = Ollama.call("Hello", [], config)
      assert message =~ "try pulling it first"
    end
  end
end
