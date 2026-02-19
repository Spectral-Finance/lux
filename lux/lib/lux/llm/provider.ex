defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal provider behaviour for LLM integrations.

  All LLM providers must implement this behaviour to be compatible with the
  Lux LLM abstraction layer. This provides a standardized interface for:

  - Reporting provider capabilities (models, features)
  - Configuring provider-specific settings
  - Health checking

  The `call/3` function is defined by `Lux.LLM` behaviour, which all providers
  already implement. This behaviour adds metadata and configuration callbacks.

  ## Implementing a Provider

      defmodule MyProvider do
        @behaviour Lux.LLM
        @behaviour Lux.LLM.Provider

        @impl Lux.LLM
        def call(prompt, tools, config) do
          # Make API call and return standardized response
          {:ok, %Lux.LLM.Provider.Response{...}}
        end

        @impl Lux.LLM.Provider
        def configured?(config) do
          not is_nil(config[:api_key])
        end

        @impl Lux.LLM.Provider
        def provider_info do
          %Lux.LLM.Provider.Info{
            name: :my_provider,
            display_name: "My Provider",
            models: [
              %Lux.LLM.Provider.ModelInfo{
                name: "my-model-v1",
                capabilities: [:chat, :tool_use],
                context_window: 128_000,
                cost_per_input_token: 0.001,
                cost_per_output_token: 0.002
              }
            ]
          }
        end
      end
  """

  alias Lux.LLM.Provider.Info

  @type config :: map()

  @doc """
  Returns whether the provider is properly configured and ready to use.

  Checks for required API keys, endpoints, etc.
  """
  @callback configured?(config()) :: boolean()

  @doc """
  Returns metadata about the provider: supported models, capabilities, pricing.
  """
  @callback provider_info() :: Info.t()

  @optional_callbacks [configured?: 1, provider_info: 0]

  @doc """
  Checks if a module implements the Provider behaviour (has call/3).
  """
  @spec provider?(module()) :: boolean()
  def provider?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :call, 3)
  end

  def provider?(_), do: false
end
