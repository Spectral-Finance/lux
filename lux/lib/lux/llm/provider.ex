defmodule Lux.LLM.Provider do
  @moduledoc """
  Behaviour that all LLM providers must implement.

  ## Callbacks

    * `name/0` – Returns an atom identifying the provider.
    * `generate/2` – Generates a completion for a given prompt.
    * `cost/1` – Returns an integer cost metric for a given response.
  """

  @callback name() :: atom()
  @callback generate(prompt :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}
  @callback cost(response :: String.t()) :: non_neg_integer()
end
