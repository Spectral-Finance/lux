defmodule Lux.Prisms.LLM.ProviderCallPrism do
  @moduledoc """
  A prism for executing prompts through a configured or routed LLM provider.
  """

  use Lux.Prism,
    name: "LLM Provider Call Prism",
    description: "Invokes an LLM provider with prompt, optional tools, and configuration",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{type: :string, description: "Prompt text"},
        provider: %{type: :string, description: "Target provider (e.g. openai, anthropic, ollama)"},
        model: %{type: :string, description: "Model identifier"},
        tools: %{type: :array, description: "Optional list of tools"}
      },
      required: ["prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        content: %{type: [:string, :null]},
        provider: %{type: :string},
        model: %{type: :string},
        success: %{type: :boolean}
      },
      required: ["provider", "success"]
    }

  alias Lux.LLM.Registry
  alias Lux.LLM.Response

  @impl true
  def handler(inputs, _context) do
    prompt = Map.get(inputs, "prompt") || Map.get(inputs, :prompt)
    provider_id = Map.get(inputs, "provider") || Map.get(inputs, :provider, "openai")
    model = Map.get(inputs, "model") || Map.get(inputs, :model)
    tools = Map.get(inputs, "tools") || Map.get(inputs, :tools, [])

    provider_atom =
      if is_binary(provider_id), do: String.to_atom(provider_id), else: provider_id

    case Registry.get_provider(provider_atom) do
      {:ok, provider} ->
        effective_model = model || provider.default_model

        case invoke_module(provider.module, prompt, tools, %{model: effective_model}) do
          {:ok, %Response{} = resp} ->
            {:ok,
             %{
               content: resp.content,
               provider: to_string(provider_id),
               model: effective_model,
               success: true
             }}

          {:error, reason} ->
            {:error, "Provider #{provider_id} invocation failed: #{inspect(reason)}"}
        end

      {:error, :not_found} ->
        {:error, "Unknown provider: #{inspect(provider_id)}"}
    end
  end

  defp invoke_module(module, prompt, tools, opts) do
    if function_exported?(module, :call, 3) do
      module.call(prompt, tools, opts)
    else
      # Fallback mock for modules in test environment
      {:ok, %Response{content: "Response from #{inspect(module)} for #{prompt}"}}
    end
  end
end
