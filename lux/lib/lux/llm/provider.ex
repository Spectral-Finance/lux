defmodule Lux.LLM.Provider do
  @moduledoc """
  Behaviour implemented by every LLM provider in Lux.

  A provider is a module that wraps a concrete LLM API (Anthropic, OpenAI,
  Together AI, Mira, ...) and exposes:

    * `c:meta/0` — machine-readable capability and pricing metadata used by
      `Lux.LLM.Selector` and `Lux.LLM.Cost`, and
    * `c:call/3` — the existing `Lux.LLM` callback, so every provider stays a
      drop-in `Lux.LLM` implementation.

  ## Example

      defmodule MyApp.LLM.MyProvider do
        @behaviour Lux.LLM
        @behaviour Lux.LLM.Provider

        @impl Lux.LLM.Provider
        def meta do
          %{
            name: :my_provider,
            models: [
              %{id: "my-model", input_cost_per_mtok: 1.0, output_cost_per_mtok: 2.0,
                max_context: 128_000, capabilities: [:tools, :json_mode]}
            ],
            supports_tools: true
          }
        end

        @impl Lux.LLM
        def call(_prompt, _tools, _options), do: {:error, :not_implemented}
      end

  """

  @typedoc """
  Per-model metadata.

    * `:id` — the model identifier as expected by the provider API
    * `:input_cost_per_mtok` / `:output_cost_per_mtok` — USD per one million
      tokens; used for cost tracking and budget enforcement
    * `:max_context` — context window in tokens
    * `:capabilities` — list of supported capabilities. Known values:
      `:tools` (function/tool calling), `:json_mode` (structured output),
      `:streaming`
  """
  @type model_meta :: %{
          required(:id) => String.t(),
          required(:input_cost_per_mtok) => number(),
          required(:output_cost_per_mtok) => number(),
          required(:max_context) => pos_integer(),
          optional(:capabilities) => [atom()]
        }

  @typedoc """
  Provider metadata.

    * `:name` — short atom used in logs, telemetry and the registry
    * `:models` — list of `t:model_meta/0`
    * `:supports_tools` — whether the provider can execute Prisms/Beams/Lenses
  """
  @type provider_meta :: %{
          required(:name) => atom(),
          required(:models) => [model_meta()],
          optional(:supports_tools) => boolean()
        }

  @doc """
  Returns the capability and pricing metadata for this provider.
  """
  @callback meta() :: provider_meta()

  @doc """
  Convenience for looking up the model metadata of the model used by a call.

  Returns `nil` when the model is not declared in `meta/0`.
  """
  @spec model_meta(module(), String.t() | nil) :: model_meta() | nil
  def model_meta(provider, model) when is_atom(provider) do
    %{models: models} = provider.meta()

    case model do
      nil -> List.first(models)
      id -> Enum.find(models, fn m -> m.id == id end)
    end
  end
end
