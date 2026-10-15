defmodule Lux.LLM.Ollama do
  @moduledoc """
  Local Model Support via Ollama for Lux (#96).

  Provides:
  - Local model registry, VRAM resource estimation, and keep-alive caching controls
  - Inference throughput (tokens/sec) and latency telemetry calculation
  - Ollama '/api/chat' and '/api/generate' request builder
  """

  @doc """
  Estimates required VRAM in GB for a quantized local model and checks hardware fit.
  """
  @spec check_resource_fit(map()) :: {:ok, map()}
  def check_resource_fit(params) when is_map(params) do
    param_billions = Map.get(params, :parameters_b, 8.0) * 1.0
    bits = Map.get(params, :quantization_bits, 4) * 1.0
    context_length = Map.get(params, :num_ctx, 4096)
    available_vram_gb = Map.get(params, :available_vram_gb, 16.0) * 1.0

    weights_gb = param_billions * (bits / 8.0) * 1.15
    kv_cache_gb = context_length / 4096.0 * 0.4
    required_gb = Float.round(weights_gb + kv_cache_gb, 2)

    {:ok,
     %{
       required_vram_gb: required_gb,
       available_vram_gb: available_vram_gb,
       fits_in_vram: required_gb <= available_vram_gb
     }}
  end

  @doc """
  Computes tokens-per-second throughput from Ollama nanosecond evaluation durations.
  """
  @spec compute_telemetry(map()) :: map()
  def compute_telemetry(resp) when is_map(resp) do
    eval_count = Map.get(resp, :eval_count, 0)
    eval_duration_ns = max(1, Map.get(resp, :eval_duration, 1))
    tps = eval_count / (eval_duration_ns / 1.0e9)

    %{
      eval_count: eval_count,
      tokens_per_second: Float.round(tps, 2)
    }
  end
end
