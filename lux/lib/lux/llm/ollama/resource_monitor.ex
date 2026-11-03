defmodule Lux.LLM.Ollama.ResourceMonitor do
  @moduledoc """
  Monitors and calculates hardware resource usage and performance telemetry
  for local Ollama inference, including token throughput, latency breakdown,
  and VRAM consumption.
  """

  alias Lux.LLM.Ollama.ModelManager

  defmodule Metrics do
    @moduledoc """
    Telemetry metrics for an Ollama inference run.
    """
    @type t :: %__MODULE__{
            total_duration_ms: float(),
            load_duration_ms: float(),
            prompt_eval_duration_ms: float(),
            eval_duration_ms: float(),
            prompt_tokens: integer(),
            eval_tokens: integer(),
            total_tokens: integer(),
            prompt_tokens_per_sec: float(),
            eval_tokens_per_sec: float()
          }

    defstruct total_duration_ms: 0.0,
              load_duration_ms: 0.0,
              prompt_eval_duration_ms: 0.0,
              eval_duration_ms: 0.0,
              prompt_tokens: 0,
              eval_tokens: 0,
              total_tokens: 0,
              prompt_tokens_per_sec: 0.0,
              eval_tokens_per_sec: 0.0
  end

  @doc """
  Extracts telemetry metrics from an Ollama response payload.
  Durations in Ollama are reported in nanoseconds.
  """
  @spec parse_metrics(map()) :: Metrics.t()
  def parse_metrics(body) when is_map(body) do
    total_ns = body["total_duration"] || 0
    load_ns = body["load_duration"] || 0
    prompt_eval_ns = body["prompt_eval_duration"] || 0
    eval_ns = body["eval_duration"] || 0

    prompt_tokens = body["prompt_eval_count"] || 0
    eval_tokens = body["eval_count"] || 0
    total_tokens = prompt_tokens + eval_tokens

    prompt_tps =
      if prompt_eval_ns > 0 and prompt_tokens > 0 do
        Float.round(prompt_tokens / (prompt_eval_ns / 1_000_000_000.0), 2)
      else
        0.0
      end

    eval_tps =
      if eval_ns > 0 and eval_tokens > 0 do
        Float.round(eval_tokens / (eval_ns / 1_000_000_000.0), 2)
      else
        0.0
      end

    %Metrics{
      total_duration_ms: Float.round(total_ns / 1_000_000.0, 2),
      load_duration_ms: Float.round(load_ns / 1_000_000.0, 2),
      prompt_eval_duration_ms: Float.round(prompt_eval_ns / 1_000_000.0, 2),
      eval_duration_ms: Float.round(eval_ns / 1_000_000.0, 2),
      prompt_tokens: prompt_tokens,
      eval_tokens: eval_tokens,
      total_tokens: total_tokens,
      prompt_tokens_per_sec: prompt_tps,
      eval_tokens_per_sec: eval_tps
    }
  end

  @doc """
  Calculates total VRAM consumption across all currently loaded models in Ollama.
  """
  @spec get_vram_usage(keyword()) :: {:ok, map()} | {:error, term()}
  def get_vram_usage(opts \\ []) do
    case ModelManager.list_running_models(opts) do
      {:ok, running_models} ->
        total_vram_bytes =
          Enum.reduce(running_models, 0, fn m, acc ->
            acc + (m.size_vram || 0)
          end)

        total_vram_mb = Float.round(total_vram_bytes / (1024 * 1024), 2)
        total_vram_gb = Float.round(total_vram_bytes / (1024 * 1024 * 1024), 3)

        {:ok,
         %{
           active_models_count: length(running_models),
           running_models: Enum.map(running_models, & &1.name),
           total_vram_bytes: total_vram_bytes,
           total_vram_mb: total_vram_mb,
           total_vram_gb: total_vram_gb
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
