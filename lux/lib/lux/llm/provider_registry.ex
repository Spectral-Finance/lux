defmodule Lux.LLM.ProviderRegistry do
  @moduledoc """
  Registry and management system for LLM providers and their supported models, capabilities,
  pricing, and runtime health status.
  """

  @default_providers %{
    open_ai: %{
      id: :open_ai,
      module: Lux.LLM.OpenAI,
      name: "OpenAI",
      status: :healthy,
      priority: 1,
      capabilities: [:tool_use, :structured_output, :streaming, :reasoning, :fast],
      models: %{
        "gpt-4o" => %{
          tier: :high,
          context_window: 128_000,
          input_cost_per_1k: 0.0025,
          output_cost_per_1k: 0.0100,
          latency_class: :balanced,
          capabilities: [:tool_use, :structured_output, :streaming, :reasoning]
        },
        "gpt-4o-mini" => %{
          tier: :low,
          context_window: 128_000,
          input_cost_per_1k: 0.00015,
          output_cost_per_1k: 0.0006,
          latency_class: :fastest,
          capabilities: [:tool_use, :structured_output, :streaming, :fast, :cost_effective]
        }
      }
    },
    anthropic: %{
      id: :anthropic,
      module: Lux.LLM.Anthropic,
      name: "Anthropic",
      status: :healthy,
      priority: 2,
      capabilities: [:tool_use, :structured_output, :streaming, :reasoning, :long_context],
      models: %{
        "claude-3-opus-20240229" => %{
          tier: :high,
          context_window: 200_000,
          input_cost_per_1k: 0.0150,
          output_cost_per_1k: 0.0750,
          latency_class: :highest_quality,
          capabilities: [:tool_use, :structured_output, :streaming, :reasoning, :long_context]
        },
        "claude-3-5-sonnet-20241022" => %{
          tier: :medium,
          context_window: 200_000,
          input_cost_per_1k: 0.0030,
          output_cost_per_1k: 0.0150,
          latency_class: :balanced,
          capabilities: [:tool_use, :structured_output, :streaming, :reasoning, :long_context]
        }
      }
    },
    together_ai: %{
      id: :together_ai,
      module: Lux.LLM.TogetherAI,
      name: "Together AI",
      status: :healthy,
      priority: 3,
      capabilities: [:tool_use, :streaming, :fast, :cost_effective],
      models: %{
        "mistral-7b-instruct" => %{
          tier: :low,
          context_window: 32_768,
          input_cost_per_1k: 0.0002,
          output_cost_per_1k: 0.0002,
          latency_class: :fastest,
          capabilities: [:tool_use, :streaming, :fast, :cost_effective]
        }
      }
    },
    mira: %{
      id: :mira,
      module: Lux.LLM.Mira,
      name: "Mira Network",
      status: :healthy,
      priority: 4,
      capabilities: [:tool_use, :streaming, :fast, :cost_effective],
      models: %{
        "llama-3.1-8b-instruct" => %{
          tier: :low,
          context_window: 128_000,
          input_cost_per_1k: 0.00018,
          output_cost_per_1k: 0.00018,
          latency_class: :fastest,
          capabilities: [:tool_use, :streaming, :fast, :cost_effective]
        }
      }
    }
  }

  @table :lux_llm_provider_registry

  @doc """
  Ensures the ETS registry table is initialized with default providers.
  """
  def ensure_started do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
        reset_defaults()

      _tid ->
        :ok
    end
  end

  @doc """
  Resets the registry to the built-in default provider definitions.
  """
  def reset_defaults do
    ensure_table_only()
    :ets.delete_all_objects(@table)

    Enum.each(@default_providers, fn {id, spec} ->
      :ets.insert(@table, {id, spec})
    end)

    :ok
  end

  @doc """
  Registers or updates a provider specification at runtime.
  """
  def register_provider(provider_id, spec) when is_atom(provider_id) and is_map(spec) do
    ensure_started()
    merged = Map.merge(%{id: provider_id, status: :healthy, priority: 10, models: %{}}, spec)
    :ets.insert(@table, {provider_id, merged})
    {:ok, merged}
  end

  @doc """
  Fetches a provider specification by atom ID.
  """
  def get_provider(provider_id) when is_atom(provider_id) do
    ensure_started()

    case :ets.lookup(@table, provider_id) do
      [{^provider_id, spec}] -> {:ok, spec}
      [] -> {:error, :provider_not_found}
    end
  end

  @doc """
  Lists all registered provider specifications sorted by priority.
  """
  def list_providers do
    ensure_started()

    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, spec} -> spec end)
    |> Enum.sort_by(& &1.priority)
  end

  @doc """
  Updates the health status (`:healthy`, `:degraded`, `:unhealthy`) of a provider.
  """
  def update_status(provider_id, status)
      when is_atom(provider_id) and status in [:healthy, :degraded, :unhealthy] do
    with {:ok, spec} <- get_provider(provider_id) do
      updated = Map.put(spec, :status, status)
      :ets.insert(@table, {provider_id, updated})
      {:ok, updated}
    end
  end

  defp ensure_table_only do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _tid ->
        :ok
    end
  end
end
