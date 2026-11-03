defmodule Lux.Beams.Llm.OpenRouterBeamTest do
  use UnitAPICase, async: true

  alias Lux.Beams.Llm.OpenRouter.OpenRouterInferenceBeam
  alias Lux.LLM.OpenRouter

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "OpenRouterInferenceBeam" do
    test "verifies beam definition and metadata" do
      assert OpenRouterInferenceBeam.name() == "OpenRouter Inference Pipeline"
      assert is_map(OpenRouterInferenceBeam.input_schema())
      assert is_map(OpenRouterInferenceBeam.output_schema())
      assert OpenRouterInferenceBeam.input_schema().required == ["prompt"]
    end

    test "executes full pipeline sequence" do
      Req.Test.stub(OpenRouter, fn conn ->
        Req.Test.json(conn, %{
          "id" => "beam-gen-1",
          "model" => "anthropic/claude-3.5-sonnet",
          "choices" => [
            %{
              "finish_reason" => "stop",
              "message" => %{
                "role" => "assistant",
                "content" => "Zero-knowledge rollups batch transactions off-chain."
              }
            }
          ],
          "usage" => %{
            "prompt_tokens" => 40,
            "completion_tokens" => 25
          }
        })
      end)

      inputs = %{
        prompt: "Explain ZK rollups",
        strategy: "smartest",
        budget_limit: 0.10,
        api_key: "sk-beam-test"
      }

      assert {:ok, result, execution_log} = OpenRouterInferenceBeam.run(inputs)
      assert execution_log.status == :completed
      assert result.content == "Zero-knowledge rollups batch transactions off-chain."
      assert result.model_used == "anthropic/claude-3.5-sonnet"
      assert result.total_cost > 0.0
      assert result.budget_exceeded == false
    end
  end
end
