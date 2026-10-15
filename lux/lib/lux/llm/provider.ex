defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal LLM provider abstraction behaviour, metadata schemas, and response normalizer.

  Defines a consistent contract across all LLM providers (`Lux.LLM.OpenAI`,
  `Lux.LLM.Anthropic`, `Lux.LLM.TogetherAI`, `Lux.LLM.Mira`, and custom providers)
  including model capability descriptors, pricing metadata, and normalized responses.
  """

  alias Lux.LLM.Anthropic
  alias Lux.LLM.Mira
  alias Lux.LLM.OpenAI
  alias Lux.LLM.Response
  alias Lux.LLM.ResponseSignal
  alias Lux.LLM.TogetherAI
  alias Lux.Signal

  defmodule ModelInfo do
    @moduledoc """
    Metadata and capability profile for a specific LLM model.
    """

    @type capability :: :tools | :json_mode | :reasoning | :fast | :vision | atom()
    @type tier :: :cheapest | :balanced | :smartest | :fast

    @type t :: %__MODULE__{
            name: String.t(),
            provider: atom(),
            tier: tier(),
            context_window: pos_integer(),
            max_output_tokens: pos_integer(),
            input_cost_per_1k: float(),
            output_cost_per_1k: float(),
            avg_latency_ms: pos_integer(),
            quality_score: float(),
            capabilities: [capability()]
          }

    defstruct name: "",
              provider: :openai,
              tier: :balanced,
              context_window: 128_000,
              max_output_tokens: 4096,
              input_cost_per_1k: 0.001,
              output_cost_per_1k: 0.002,
              avg_latency_ms: 800,
              quality_score: 0.85,
              capabilities: [:tools, :json_mode]
  end

  defmodule Spec do
    @moduledoc """
    Registration specification for an LLM provider in `Lux.LLM.ProviderRegistry`.
    """

    alias Lux.LLM.OpenAI
    alias Lux.LLM.Provider.ModelInfo

    @type t :: %__MODULE__{
            id: atom(),
            module: module(),
            default_model: String.t(),
            models: [ModelInfo.t()],
            enabled: boolean(),
            priority: integer(),
            failure_count: non_neg_integer(),
            last_failure_at: integer() | nil,
            circuit_breaker_threshold: pos_integer(),
            circuit_breaker_cooldown_ms: pos_integer(),
            default_config: map()
          }

    defstruct id: :openai,
              module: OpenAI,
              default_model: "gpt-4o-mini",
              models: [],
              enabled: true,
              priority: 100,
              failure_count: 0,
              last_failure_at: nil,
              circuit_breaker_threshold: 3,
              circuit_breaker_cooldown_ms: 30_000,
              default_config: %{}
  end

  @type prompt :: String.t() | [map()]
  @type tools :: [Lux.Prism.t() | Lux.Beam.t() | Lux.Lens.t() | module()]
  @type config :: map()

  @callback call(prompt(), tools(), config()) :: {:ok, term()} | {:error, term()}
  @callback provider_id() :: atom()
  @callback supported_models() :: [ModelInfo.t()]
  @callback estimate_cost(String.t(), non_neg_integer(), non_neg_integer()) :: float()

  @optional_callbacks provider_id: 0, supported_models: 0, estimate_cost: 3

  @doc """
  Returns the built-in default provider specifications for OpenAI, Anthropic,
  TogetherAI, and Mira.
  """
  @spec default_provider_specs() :: [Spec.t()]
  def default_provider_specs do
    [
      openai_spec(),
      anthropic_spec(),
      together_ai_spec(),
      mira_spec()
    ]
  end

  @doc """
  Normalizes a provider response into a consistent `%Lux.LLM.Response{}` struct
  while preserving raw signal metadata when needed.
  """
  @spec normalize_response(term(), atom()) :: {:ok, Response.t()} | {:error, term()}
  def normalize_response({:ok, %Response{} = response}, _provider) do
    {:ok, response}
  end

  def normalize_response(
        {:ok, %Signal{schema_id: ResponseSignal, payload: payload}},
        _provider
      ) do
    content =
      case payload[:content] do
        text when is_binary(text) -> text
        %{"text" => text} when is_binary(text) -> text
        map when is_map(map) -> Jason.encode!(map)
        other -> other
      end

    structured_output =
      if is_map(payload[:content]) do
        payload[:content]
      else
        nil
      end

    tool_calls = normalize_tool_calls(payload[:tool_calls])

    {:ok,
     %Response{
       content: content,
       tool_calls: tool_calls,
       finish_reason: payload[:finish_reason],
       structured_output: structured_output
     }}
  end

  def normalize_response({:error, _reason} = error, _provider), do: error
  def normalize_response(other, _provider), do: {:error, {:unexpected_response, other}}

  @doc """
  Extracts token usage from a provider response if present.
  """
  @spec extract_usage(term()) :: %{
          prompt_tokens: non_neg_integer(),
          completion_tokens: non_neg_integer(),
          total_tokens: non_neg_integer()
        }
  def extract_usage(%Signal{metadata: %{usage: usage}}) when is_map(usage) do
    prompt = Map.get(usage, "prompt_tokens") || Map.get(usage, :prompt_tokens) || 0
    completion = Map.get(usage, "completion_tokens") || Map.get(usage, :completion_tokens) || 0
    total = Map.get(usage, "total_tokens") || Map.get(usage, :total_tokens) || prompt + completion

    %{
      prompt_tokens: prompt,
      completion_tokens: completion,
      total_tokens: total
    }
  end

  def extract_usage(_response) do
    %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}
  end

  defp normalize_tool_calls(nil), do: []
  defp normalize_tool_calls([]), do: []

  defp normalize_tool_calls(tool_calls) when is_list(tool_calls) do
    Enum.map(tool_calls, fn
      %{type: _, name: _, params: _} = normalized ->
        normalized

      %{"function" => %{"name" => name, "arguments" => args}} ->
        params =
          case Jason.decode(args) do
            {:ok, decoded} -> decoded
            _ -> %{"raw" => args}
          end

        %{type: "function", name: name, params: params}

      other ->
        %{type: "function", name: "unknown", params: Map.new(other)}
    end)
  end

  defp openai_spec do
    %Spec{
      id: :openai,
      module: OpenAI,
      default_model: "gpt-4o-mini",
      priority: 100,
      models: [
        %ModelInfo{
          name: "gpt-4o-mini",
          provider: :openai,
          tier: :cheapest,
          context_window: 128_000,
          max_output_tokens: 16_384,
          input_cost_per_1k: 0.00015,
          output_cost_per_1k: 0.0006,
          avg_latency_ms: 450,
          quality_score: 0.82,
          capabilities: [:tools, :json_mode, :fast, :vision]
        },
        %ModelInfo{
          name: "gpt-4o",
          provider: :openai,
          tier: :smartest,
          context_window: 128_000,
          max_output_tokens: 16_384,
          input_cost_per_1k: 0.0025,
          output_cost_per_1k: 0.01,
          avg_latency_ms: 850,
          quality_score: 0.96,
          capabilities: [:tools, :json_mode, :reasoning, :vision]
        },
        %ModelInfo{
          name: "gpt-4",
          provider: :openai,
          tier: :balanced,
          context_window: 128_000,
          max_output_tokens: 8192,
          input_cost_per_1k: 0.01,
          output_cost_per_1k: 0.03,
          avg_latency_ms: 1100,
          quality_score: 0.92,
          capabilities: [:tools, :json_mode, :reasoning]
        }
      ]
    }
  end

  defp anthropic_spec do
    %Spec{
      id: :anthropic,
      module: Anthropic,
      default_model: "claude-3-sonnet-20240229",
      priority: 90,
      models: [
        %ModelInfo{
          name: "claude-3-haiku-20240307",
          provider: :anthropic,
          tier: :cheapest,
          context_window: 200_000,
          max_output_tokens: 4096,
          input_cost_per_1k: 0.00025,
          output_cost_per_1k: 0.00125,
          avg_latency_ms: 400,
          quality_score: 0.80,
          capabilities: [:tools, :fast, :vision]
        },
        %ModelInfo{
          name: "claude-3-sonnet-20240229",
          provider: :anthropic,
          tier: :balanced,
          context_window: 200_000,
          max_output_tokens: 4096,
          input_cost_per_1k: 0.003,
          output_cost_per_1k: 0.015,
          avg_latency_ms: 750,
          quality_score: 0.91,
          capabilities: [:tools, :reasoning, :vision]
        },
        %ModelInfo{
          name: "claude-3-opus-20240229",
          provider: :anthropic,
          tier: :smartest,
          context_window: 200_000,
          max_output_tokens: 4096,
          input_cost_per_1k: 0.015,
          output_cost_per_1k: 0.075,
          avg_latency_ms: 1400,
          quality_score: 0.97,
          capabilities: [:tools, :reasoning, :vision]
        }
      ]
    }
  end

  defp together_ai_spec do
    %Spec{
      id: :together_ai,
      module: TogetherAI,
      default_model: "mistralai/Mistral-7B-Instruct-v0.2",
      priority: 80,
      models: [
        %ModelInfo{
          name: "mistralai/Mistral-7B-Instruct-v0.2",
          provider: :together_ai,
          tier: :cheapest,
          context_window: 32_768,
          max_output_tokens: 4096,
          input_cost_per_1k: 0.0002,
          output_cost_per_1k: 0.0002,
          avg_latency_ms: 350,
          quality_score: 0.76,
          capabilities: [:tools, :fast]
        },
        %ModelInfo{
          name: "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo",
          provider: :together_ai,
          tier: :balanced,
          context_window: 128_000,
          max_output_tokens: 4096,
          input_cost_per_1k: 0.00088,
          output_cost_per_1k: 0.00088,
          avg_latency_ms: 550,
          quality_score: 0.89,
          capabilities: [:tools, :json_mode, :reasoning]
        }
      ]
    }
  end

  defp mira_spec do
    %Spec{
      id: :mira,
      module: Mira,
      default_model: "llama-3.1-8b-instruct",
      priority: 70,
      models: [
        %ModelInfo{
          name: "llama-3.1-8b-instruct",
          provider: :mira,
          tier: :cheapest,
          context_window: 32_768,
          max_output_tokens: 4096,
          input_cost_per_1k: 0.0001,
          output_cost_per_1k: 0.0001,
          avg_latency_ms: 320,
          quality_score: 0.75,
          capabilities: [:tools, :fast]
        }
      ]
    }
  end
end
