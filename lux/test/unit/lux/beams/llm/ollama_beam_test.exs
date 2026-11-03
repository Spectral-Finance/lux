defmodule Lux.Beams.Llm.OllamaBeamTest do
  use UnitAPICase, async: true

  alias Lux.Beams.Llm.Ollama.OllamaLocalInferenceBeam
  alias Lux.LLM.Ollama
  alias Lux.LLM.Ollama.ModelManager

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "OllamaLocalInferenceBeam" do
    test "verifies beam configuration" do
      assert OllamaLocalInferenceBeam.name() == "Ollama Local Inference Pipeline"
      assert is_map(OllamaLocalInferenceBeam.input_schema())
      assert is_map(OllamaLocalInferenceBeam.output_schema())
      assert OllamaLocalInferenceBeam.input_schema().required == ["prompt"]
    end

    test "executes full local pipeline" do
      # 1. Model check
      Req.Test.stub(ModelManager, fn conn ->
        if String.contains?(conn.request_path, "/api/tags") do
          Req.Test.json(conn, %{"models" => [%{"name" => "llama3.2:latest"}]})
        else
          # /api/ps
          Req.Test.json(conn, %{"models" => [%{"name" => "llama3.2:latest", "size_vram" => 1_500_000_000}]})
        end
      end)

      # 2. Preload & Chat
      Req.Test.stub(Ollama, fn conn ->
        if String.contains?(conn.request_path, "/api/generate") do
          Req.Test.json(conn, %{"status" => "success"})
        else
          Req.Test.json(conn, %{
            "model" => "llama3.2",
            "message" => %{
              "role" => "assistant",
              "content" => "Local transaction parsed successfully."
            },
            "done" => true,
            "total_duration" => 180_000_000,
            "eval_count" => 20,
            "eval_duration" => 100_000_000
          })
        end
      end)

      inputs = %{
        prompt: "Parse transaction",
        model: "llama3.2",
        temperature: 0.1
      }

      assert {:ok, result, execution_log} = OllamaLocalInferenceBeam.run(inputs)
      assert execution_log.status == :completed
      assert result.content == "Local transaction parsed successfully."
      assert result.model == "llama3.2"
    end
  end
end
