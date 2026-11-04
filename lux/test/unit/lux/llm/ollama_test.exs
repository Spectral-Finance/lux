defmodule Lux.LLM.OllamaTest do
  use UnitAPICase, async: false

  alias Lux.LLM.Ollama

  setup do
    Ollama.clear_cache()
    Req.Test.verify_on_exit!()
  end

  describe "local inference, caching, and resource controls" do
    test "calls /api/chat with resource controls, computes tokens/sec metrics, and caches response" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        {:ok, raw_body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(raw_body)
        assert decoded["model"] == "llama3.2"
        assert decoded["options"]["num_ctx"] == 8192
        assert decoded["options"]["num_gpu"] == 1

        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "created_at" => "2026-11-04T00:00:00Z",
          "done" => true,
          "message" => %{
            "role" => "assistant",
            "content" => "{\"verdict\":\"local_inference_ok\"}"
          },
          "prompt_eval_count" => 24,
          "eval_count" => 50,
          "eval_duration" => 500_000_000,
          "total_duration" => 650_000_000
        })
      end)

      Application.put_env(:lux, Ollama, plug: {Req.Test, Ollama})

      assert {:ok, signal} =
               Ollama.call("Run local check", [], %{
                 model: "llama3.2",
                 num_ctx: 8192,
                 num_gpu: 1,
                 cache: true
               })

      assert signal.payload.content == %{"verdict" => "local_inference_ok"}
      assert signal.metadata.usage.tokens_per_sec == 100.0

      # Second identical call is served from ETS cache without HTTP roundtrip
      assert {:ok, cached_signal} =
               Ollama.call("Run local check", [], %{
                 model: "llama3.2",
                 num_ctx: 8192,
                 num_gpu: 1,
                 cache: true
               })

      assert cached_signal == signal
    end
  end

  describe "local model management" do
    test "lists, pulls, and deletes local models" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/tags"
        Req.Test.json(conn, %{"models" => [%{"name" => "llama3.2:latest"}]})
      end)

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/pull"
        Req.Test.json(conn, %{"status" => "success"})
      end)

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/delete"
        Req.Test.json(conn, %{})
      end)

      Application.put_env(:lux, Ollama, plug: {Req.Test, Ollama})

      assert {:ok, [%{"name" => "llama3.2:latest"}]} = Ollama.list_models()
      assert {:ok, %{"status" => "success"}} = Ollama.pull_model("llama3.2")
      assert {:ok, %{deleted: "llama3.2"}} = Ollama.delete_model("llama3.2")
    end
  end
end
