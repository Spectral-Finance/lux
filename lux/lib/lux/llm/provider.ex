defmodule Lux.LLM.ModelConfig do
  @moduledoc """
  Configuration struct for an LLM model offered by a provider.
  """

  @type capability :: :tools | :json_schema | :streaming | :vision | :reasoning | atom()

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          provider_id: atom(),
          cost_per_1k_prompt_tokens: float(),
          cost_per_1k_completion_tokens: float(),
          capabilities: [capability()],
          context_window: integer()
        }

  defstruct [
    :id,
    :name,
    :provider_id,
    cost_per_1k_prompt_tokens: 0.0,
    cost_per_1k_completion_tokens: 0.0,
    capabilities: [:tools, :json_schema],
    context_window: 128_000
  ]
end

defmodule Lux.LLM.ProviderConfig do
  @moduledoc """
  Configuration struct for a registered LLM provider.
  """

  @type status :: :active | :inactive | :disabled | atom()

  @type t :: %__MODULE__{
          id: atom(),
          module: module(),
          api_key: String.t() | nil,
          endpoint: String.t() | nil,
          models: [Lux.LLM.ModelConfig.t()],
          status: status()
        }

  defstruct [
    :id,
    :module,
    :api_key,
    :endpoint,
    models: [],
    status: :active
  ]
end

defmodule Lux.LLM.Provider do
  @moduledoc """
  Behaviour interface for LLM provider implementations in Lux.
  """

  alias Lux.LLM.ModelConfig
  alias Lux.Signal

  @type prompt :: String.t() | [map()]
  @type tools :: [Lux.Prism.t() | Lux.Beam.t() | Lux.Lens.t() | map() | module() | tuple()]
  @type opts :: map() | keyword()

  @callback id() :: atom()
  @callback models() :: [ModelConfig.t()]
  @callback call(prompt :: prompt(), tools :: tools(), opts :: opts()) ::
              {:ok, Signal.t()} | {:error, term()}
end
