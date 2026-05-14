defmodule Lux.LLM.OllamaTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Ollama
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
    Application.put_env(:lux, Ollama, plug: {Req.Test, Ollama})
    Ollama.clear_model_cache()
    Req.Test.verify_on_exit!()
  end

  describe "call/3" do
    test "calls the local Ollama chat API with resource controls" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "llama3.2"
        assert decoded["messages"] == [%{"role" => "user", "content" => "hello"}]
        assert decoded["stream"] == false
        assert decoded["keep_alive"] == "10m"
        assert decoded["options"]["num_ctx"] == 4096
        assert decoded["options"]["temperature"] == 0.2

        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "created_at" => "2026-05-14T00:00:00Z",
          "message" => %{"role" => "assistant", "content" => ~s({"answer":"local"})},
          "done" => true,
          "done_reason" => "stop",
          "total_duration" => 2_000_000_000,
          "load_duration" => 500_000_000,
          "prompt_eval_count" => 4,
          "prompt_eval_duration" => 200_000_000,
          "eval_count" => 10,
          "eval_duration" => 1_000_000_000
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"answer" => "local"},
                  finish_reason: "stop",
                  model: "llama3.2",
                  tool_calls: nil,
                  tool_calls_results: nil
                },
                metadata: %{performance: %{tokens_per_second: 10.0, total_duration_ms: 2000.0}}
              }} =
               Ollama.call("hello", [], %{
                 model: "llama3.2",
                 temperature: 0.2,
                 num_ctx: 4096,
                 keep_alive: "10m"
               })
    end

    test "wraps plain text responses in a response object" do
      Req.Test.expect(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{"role" => "assistant", "content" => "plain answer"},
          "done" => true
        })
      end)

      assert {:ok, %Signal{payload: %{content: %{"text" => "plain answer"}}}} =
               Ollama.call("hello", [], %{model: "llama3.2"})
    end
  end

  describe "model management" do
    test "lists and caches local models" do
      Req.Test.expect(Ollama, 1, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/tags"

        Req.Test.json(conn, %{
          "models" => [
            %{
              "name" => "llama3.2",
              "modified_at" => "2026-05-14T00:00:00Z",
              "size" => 1_000,
              "digest" => "sha256:test"
            }
          ]
        })
      end)

      assert {:ok, [%{name: "llama3.2", size: 1_000}], :refreshed} = Ollama.cached_models()
      assert {:ok, [%{name: "llama3.2", size: 1_000}], :cache_hit} = Ollama.cached_models()
    end

    test "pulls a missing model when ensure_model cannot find it locally" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.request_path == "/api/tags"
        Req.Test.json(conn, %{"models" => []})
      end)

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/pull"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"model" => "mistral", "stream" => false}

        Req.Test.json(conn, %{"status" => "success"})
      end)

      assert {:ok, %{model: "mistral", status: :pulled, pull: %{"status" => "success"}}} =
               Ollama.ensure_model("mistral")
    end

    test "shows and deletes models" do
      Req.Test.expect(Ollama, fn conn ->
        assert conn.request_path == "/api/show"
        Req.Test.json(conn, %{"modelfile" => "FROM llama3.2"})
      end)

      assert {:ok, %{"modelfile" => "FROM llama3.2"}} = Ollama.show_model("llama3.2")

      Req.Test.expect(Ollama, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/delete"
        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert {:ok, %{deleted: "llama3.2"}} = Ollama.delete_model("llama3.2")
    end
  end

  test "builds resource plans with warnings" do
    plan = Ollama.resource_plan(model: "llama3.2", num_ctx: 65_536, num_predict: 10_000)

    assert plan.model == "llama3.2"
    assert plan.options.num_ctx == 65_536
    assert "num_ctx is high; local memory pressure likely" in plan.warnings
    assert "num_predict is high; long generations can monopolize local compute" in plan.warnings
  end

  test "converts prisms to Ollama function tools" do
    assert %{
             type: "function",
             function: %{name: "Lux_LLM_OllamaTest_TestPrism", description: "A test prism"}
           } = Ollama.tool_to_function(TestPrism.view())
  end
end
