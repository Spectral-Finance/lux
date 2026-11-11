defmodule Lux.LLM.Ollama.ModelManagerTest do
  use UnitCase, async: false

  alias Lux.LLM.Ollama.ModelManager

  setup do
    ModelManager.clear_cache()
    :ok
  end

  test "list_models/1 fetches and caches local models from /api/tags" do
    Req.Test.stub(Lux.LLM.Ollama.ModelManager, fn conn ->
      Req.Test.json(conn, %{
        "models" => [
          %{"name" => "llama3.2:latest", "size" => 2_000_000_000},
          %{"name" => "nomic-embed-text:latest", "size" => 274_000_000}
        ]
      })
    end)

    Application.put_env(:lux, Lux.LLM.Ollama.ModelManager,
      plug: {Req.Test, Lux.LLM.Ollama.ModelManager}
    )

    assert {:ok, models} = ModelManager.list_models()
    assert length(models) == 2
    assert ModelManager.model_available?("llama3.2")
    assert ModelManager.model_available?("nomic-embed-text:latest")
    refute ModelManager.model_available?("mistral:7b")
  end

  test "pull_model/2, show_model/2, and delete_model/2 interact with Ollama endpoints" do
    Req.Test.stub(Lux.LLM.Ollama.ModelManager, fn conn ->
      case {conn.method, conn.request_path} do
        {"POST", "/api/pull"} ->
          Req.Test.json(conn, %{"status" => "success"})

        {"POST", "/api/show"} ->
          Req.Test.json(conn, %{
            "modelfile" => "FROM llama3.2",
            "details" => %{"family" => "llama", "parameter_size" => "3.2B"}
          })

        {"DELETE", "/api/delete"} ->
          Plug.Conn.send_resp(conn, 200, "")
      end
    end)

    Application.put_env(:lux, Lux.LLM.Ollama.ModelManager,
      plug: {Req.Test, Lux.LLM.Ollama.ModelManager}
    )

    assert {:ok, %{"status" => "success"}} = ModelManager.pull_model("llama3.2")
    assert {:ok, %{"details" => %{"family" => "llama"}}} = ModelManager.show_model("llama3.2")
    assert :ok = ModelManager.delete_model("llama3.2")
  end
end
