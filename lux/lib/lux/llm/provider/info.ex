defmodule Lux.LLM.Provider.Info do
  @moduledoc """
  Metadata about an LLM provider, including its supported models and capabilities.
  """

  alias Lux.LLM.Provider.ModelInfo

  @type t :: %__MODULE__{
          name: atom(),
          display_name: String.t(),
          module: module() | nil,
          models: [ModelInfo.t()],
          default_model: String.t() | nil,
          base_url: String.t() | nil
        }

  defstruct name: nil,
            display_name: "",
            module: nil,
            models: [],
            default_model: nil,
            base_url: nil

  @doc """
  Finds a model by name within this provider's model list.
  """
  @spec find_model(t(), String.t()) :: ModelInfo.t() | nil
  def find_model(%__MODULE__{models: models}, model_name) do
    Enum.find(models, fn m -> m.name == model_name end)
  end
end

defmodule Lux.LLM.Provider.ModelInfo do
  @moduledoc """
  Information about a specific model offered by a provider.

  ## Capabilities

  Models can advertise one or more capabilities:

  - `:chat` - Standard chat/completion
  - `:tool_use` - Function/tool calling
  - `:vision` - Image understanding
  - `:streaming` - Streaming responses
  - `:json_mode` - Structured JSON output
  - `:reasoning` - Extended thinking/reasoning
  """

  @type capability :: :chat | :tool_use | :vision | :streaming | :json_mode | :reasoning

  @type t :: %__MODULE__{
          name: String.t(),
          capabilities: [capability()],
          context_window: non_neg_integer(),
          max_output_tokens: non_neg_integer() | nil,
          cost_per_input_token: float(),
          cost_per_output_token: float()
        }

  defstruct name: "",
            capabilities: [:chat],
            context_window: 4096,
            max_output_tokens: nil,
            cost_per_input_token: 0.0,
            cost_per_output_token: 0.0
end
