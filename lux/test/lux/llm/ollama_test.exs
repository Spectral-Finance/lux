defmodule Lux.LLM.OllamaTest.Tool do
  use Lux.Prism,
    name: "Ollama Test Tool",
    description: "Returns its arguments",
    input_schema: %{type: :object, properties: %{value: %{type: :string}}},
    output_schema: %{type: :object, properties: %{value: %{type: :string}}}

  def handler(args, _context), do: {:ok, args}
end

defmodule Lux.LLM.OllamaTest do
  use ExUnit.Case, async: false

  alias Lux.LLM.Ollama
  alias Lux.LLM.OllamaTest.Tool

  setup do
    previous = Application.get_env(:lux, Ollama)
    Application.put_env(:lux, Ollama, plug: {Req.Test, __MODULE__})
    Ollama.clear_performance_metrics()
    Req.Test.verify_on_exit!()

    on_exit(fn ->
      if previous,
        do: Application.put_env(:lux, Ollama, previous),
        else: Application.delete_env(:lux, Ollama)

      Ollama.clear_performance_metrics()
    end)

    :ok
  end

  test "builds a usable Config with all call fields" do
    config = %Ollama.Config{}
    assert config.endpoint == "http://localhost:11434"
    assert config.model == "llama3.3"
    assert config.api_key == nil
    assert config.system == nil
  end

  test "chat sends format, keep_alive and resource options and records metrics" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/chat"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)

      assert payload["format"] == "json"
      assert payload["keep_alive"] == "5m"
      assert payload["options"]["num_ctx"] == 2048
      assert payload["options"]["num_predict"] == 64
      assert payload["options"]["temperature"] == 0.2

      Req.Test.json(conn, %{
        "model" => "llama3.2",
        "message" => %{"content" => "hello"},
        "prompt_eval_count" => 3,
        "eval_count" => 2
      })
    end)

    assert {:ok, signal} =
             Ollama.call("hi", [], %{
               model: "llama3.2",
               format: "json",
               keep_alive: "5m",
               num_ctx: 2048,
               max_tokens: 64,
               temperature: 0.2
             })

    assert signal.payload.content == %{"text" => "hello"}

    assert [%{model: "llama3.2", prompt_tokens: 3, output_tokens: 2}] =
             Ollama.performance_metrics()
  end

  test "executes map arguments and completes assistant-tool-follow-up round trip" do
    Req.Test.expect(__MODULE__, 2, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)

      case payload["messages"] do
        [_, %{"role" => "user"}] ->
          assert [%{"type" => "function"}] = payload["tools"]

          Req.Test.json(conn, %{
            "model" => "llama3.3",
            "message" => %{
              "content" => "",
              "tool_calls" => [
                %{
                  "function" => %{
                    "name" => "Lux_LLM_OllamaTest_Tool",
                    "arguments" => %{"value" => "map"}
                  }
                }
              ]
            }
          })

        messages ->
          assert %{"role" => "assistant", "tool_calls" => [_]} = Enum.at(messages, 2)
          assert %{"role" => "tool", "content" => content} = Enum.at(messages, 3)
          assert Jason.decode!(content) == %{"value" => "map"}

          Req.Test.json(conn, %{
            "model" => "llama3.3",
            "message" => %{"content" => "done"},
            "prompt_eval_count" => 4,
            "eval_count" => 1
          })
      end
    end)

    assert {:ok, signal} = Ollama.call("use tool", [Tool], %{})
    assert signal.payload.content == %{"text" => "done"}
    assert signal.payload.tool_calls_results == [%{"value" => "map"}]
  end

  test "accepts JSON-string tool arguments" do
    Req.Test.expect(__MODULE__, 2, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)

      if length(payload["messages"]) == 2 do
        Req.Test.json(conn, %{
          "model" => "llama3.3",
          "message" => %{
            "content" => "",
            "tool_calls" => [
              %{
                "function" => %{
                  "name" => "Lux_LLM_OllamaTest_Tool",
                  "arguments" => ~s({"value":"json"})
                }
              }
            ]
          }
        })
      else
        Req.Test.json(conn, %{"model" => "llama3.3", "message" => %{"content" => "done"}})
      end
    end)

    assert {:ok, signal} = Ollama.call("use tool", [Tool], %{})
    assert signal.payload.tool_calls_results == [%{"value" => "json"}]
  end

  test "model management uses Ollama API fields and parses NDJSON pull progress" do
    Req.Test.expect(__MODULE__, 2, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body)["model"] == "llama3.2"

      case conn.request_path do
        "/api/pull" ->
          if Jason.decode!(body)["stream"] do
            Plug.Conn.send_resp(
              conn,
              200,
              ~s({"status":"pulling","completed":1}\n{"status":"success"}\n)
            )
          else
            Req.Test.json(conn, %{"status" => "success"})
          end
      end
    end)

    assert {:ok, %{"status" => "success"}} = Ollama.pull_model("llama3.2")
    assert {:ok, stream} = Ollama.pull_model_stream("llama3.2")

    assert Enum.to_list(stream) == [
             %{"status" => "pulling", "completed" => 1},
             %{"status" => "success"}
           ]
  end
end
