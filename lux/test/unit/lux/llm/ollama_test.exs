defmodule Lux.LLM.OllamaTest do
  use ExUnit.Case, async: true
  alias Lux.LLM.Ollama

  test "validates VRAM resource fit and computes tokens/sec telemetry" do
    {:ok, fit} =
      Ollama.check_resource_fit(%{
        parameters_b: 8.0,
        quantization_bits: 4,
        num_ctx: 8192,
        available_vram_gb: 8.0
      })

    assert fit.fits_in_vram == true
    assert fit.required_vram_gb < 8.0

    metrics = Ollama.compute_telemetry(%{eval_count: 150, eval_duration: 3_000_000_000})
    assert metrics.tokens_per_second == 50.0
  end
end
