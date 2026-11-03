defmodule Lux.LLM.ModelSelector do
  @moduledoc """
  Automatic model selection engine based on user requirements, latency, cost, and reasoning power.
  """

  @model_catalog [
    %{
      provider: :openai,
      model: "gpt-4o-mini",
      tier: :cost_optimized,
      input_cost_per_m: 0.15,
      output_cost_per_m: 0.60,
      avg_latency_ms: 350,
      context_window: 128_000,
      capabilities: [:tools, :structured_output, :vision, :json_mode]
    },
    %{
      provider: :openai,
      model: "gpt-4o",
      tier: :balanced,
      input_cost_per_m: 2.50,
      output_cost_per_m: 10.00,
      avg_latency_ms: 600,
      context_window: 128_000,
      capabilities: [:tools, :structured_output, :vision, :json_mode]
    },
    %{
      provider: :openai,
      model: "o1",
      tier: :reasoning_optimized,
      input_cost_per_m: 15.00,
      output_cost_per_m: 60.00,
      avg_latency_ms: 2500,
      context_window: 200_000,
      capabilities: [:tools, :reasoning]
    },
    %{
      provider: :anthropic,
      model: "claude-3-5-sonnet-20241022",
      tier: :reasoning_optimized,
      input_cost_per_m: 3.00,
      output_cost_per_m: 15.00,
      avg_latency_ms: 700,
      context_window: 200_000,
      capabilities: [:tools, :vision, :prompt_caching]
    },
    %{
      provider: :anthropic,
      model: "claude-3-5-haiku-20241022",
      tier: :cost_optimized,
      input_cost_per_m: 0.80,
      output_cost_per_m: 4.00,
      avg_latency_ms: 300,
      context_window: 200_000,
      capabilities: [:tools, :vision]
    },
    %{
      provider: :groq,
      model: "llama-3.3-70b-versatile",
      tier: :latency_optimized,
      input_cost_per_m: 0.59,
      output_cost_per_m: 0.79,
      avg_latency_ms: 180,
      context_window: 128_000,
      capabilities: [:tools, :fast_inference]
    }
  ]

  @doc """
  Selects best model matching optimization strategy and required capabilities.
  """
  @spec select_model(map()) :: {:ok, map()} | {:error, :no_matching_model}
  def select_model(criteria \\ %{}) do
    tier = Map.get(criteria, :strategy) || Map.get(criteria, "strategy", :balanced)
    required_caps = Map.get(criteria, :required_capabilities) || Map.get(criteria, "required_capabilities", [])
    max_cost = Map.get(criteria, :max_input_cost_per_m) || Map.get(criteria, "max_input_cost_per_m", 100.0)

    candidates =
      @model_catalog
      |> Enum.filter(fn m ->
        caps_match? = Enum.all?(required_caps, fn cap -> cap in m.capabilities end)
        cost_ok? = m.input_cost_per_m <= max_cost
        caps_match? and cost_ok?
      end)

    matched =
      Enum.find(candidates, fn m -> m.tier == tier end) ||
        List.first(candidates)

    case matched do
      nil -> {:error, :no_matching_model}
      model -> {:ok, model}
    end
  end

  @doc """
  Lists all models in catalog.
  """
  @spec list_catalog() :: list(map())
  def list_catalog, do: @model_catalog
end
