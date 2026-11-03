defmodule Lux.Prisms.Llm.OllamaPrismsTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Ollama
  alias Lux.LLM.Ollama.ModelManager
  alias Lux.Prisms.Llm.Ollama.BenchmarkPrism
  alias Lux.Prisms.Llm.Ollama.ChatPrism
  alias Lux.Prisms.Llm.Ollama.ModelCachePrism
  alias Lux.Prisms.Llm.Ollama.ModelManagePrism
  alias Lux.Prisms.Llm.Ollama.ResourceMonitorPrism

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "ChatPrism" do
    test "executes local chat completion and returns metrics" do
      Req.Test.stub(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{"role" => "assistant", "content" => "Local response"},
          "done" => true,
          "total_duration" => 150_000_000,
          "eval_count" => 30,
          "eval_duration" => 100_000_000
        })
      end)

      inputs = %{
        "prompt" => "Hello",
        "model" => "llama3.2"
      }

      assert {:ok, result} = ChatPrism.handler(inputs, %{})
      assert result.content == "Local response"
      assert result.model == "llama3.2"
      assert result.metrics[:eval_tokens_per_sec] == 300.0
    end
  end

  describe "ModelManagePrism" do
    test "lists models" do
      Req.Test.stub(ModelManager, fn conn ->
        Req.Test.json(conn, %{
          "models" => [
            %{
              "name" => "llama3.2:latest",
              "size" => 2_147_483_648,
              "details" => %{"family" => "llama", "parameter_size" => "3.2B"}
            }
          ]
        })
      end)

      assert {:ok, result} = ModelManagePrism.handler(%{"action" => "list"}, %{})
      assert result.status == "success"
      assert length(result.models) == 1
      assert hd(result.models).name == "llama3.2:latest"
    end

    test "checks model installation" do
      Req.Test.stub(ModelManager, fn conn ->
        Req.Test.json(conn, %{"models" => [%{"name" => "llama3.2:latest"}]})
      end)

      assert {:ok, result} =
               ModelManagePrism.handler(%{"action" => "check", "model_name" => "llama3.2"}, %{})

      assert result.installed == true
    end
  end

  describe "ResourceMonitorPrism" do
    test "inspects active VRAM usage and running models" do
      Req.Test.stub(ModelManager, fn conn ->
        Req.Test.json(conn, %{
          "models" => [
            %{"name" => "llama3.2:latest", "size_vram" => 1_073_741_824}
          ]
        })
      end)

      assert {:ok, result} = ResourceMonitorPrism.handler(%{}, %{})
      assert result.healthy == true
      assert result.active_models_count == 1
      assert result.total_vram_gb == 1.0
    end
  end

  describe "ModelCachePrism" do
    test "preloads and unloads models" do
      Req.Test.stub(Ollama, fn conn ->
        Req.Test.json(conn, %{"status" => "success"})
      end)

      assert {:ok, result} =
               ModelCachePrism.handler(%{"action" => "preload", "model_name" => "llama3.2"}, %{})

      assert result.status == "preloaded"

      assert {:ok, un_res} =
               ModelCachePrism.handler(%{"action" => "unload", "model_name" => "llama3.2"}, %{})

      assert un_res.status == "unloaded"
    end
  end

  describe "BenchmarkPrism" do
    test "measures tokens per sec throughput" do
      Req.Test.stub(Ollama, fn conn ->
        Req.Test.json(conn, %{
          "model" => "llama3.2",
          "message" => %{"role" => "assistant", "content" => "1, 2, 3"},
          "done" => true,
          "total_duration" => 250_000_000,
          "eval_count" => 50,
          "eval_duration" => 200_000_000
        })
      end)

      assert {:ok, result} =
               BenchmarkPrism.handler(%{"model" => "llama3.2", "num_predict" => 50}, %{})

      assert result.model == "llama3.2"
      assert result.eval_tokens_per_sec == 250.0
      assert result.tokens_generated == 50
    end
  end
end
