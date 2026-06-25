defmodule Lux.LLM.ProviderConfig do
  @moduledoc """
  Configuration structure for LLM providers.
  """

  defstruct [
    :name,
    :module,
    :api_key,
    :base_url,
    :default_model,
    :models,
    :rate_limit,
    :timeout,
    :retry_policy,
    :cost_per_token,
    :metadata
  ]

  @type t :: %__MODULE__{
          name: atom(),
          module: module(),
          api_key: String.t() | nil,
          base_url: String.t() | nil,
          default_model: String.t() | nil,
          models: [String.t()],
          rate_limit: pos_integer() | nil,
          timeout: pos_integer(),
          retry_policy: keyword(),
          cost_per_token: map() | nil,
          metadata: map()
        }

  @doc """
  Creates a new provider configuration.
  """
  def new(attrs) do
    struct!(__MODULE__, Map.merge(defaults(), attrs))
  end

  @doc """
  Default configuration values.
  """
  def defaults do
    %{
      models: [],
      timeout: 30_000,
      retry_policy: [max_retries: 3, backoff: :exponential],
      metadata: %{}
    }
  end
end