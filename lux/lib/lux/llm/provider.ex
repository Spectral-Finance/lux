defmodule Lux.LLM.Provider do
  @moduledoc """
  Defines the behaviour for universal LLM providers in Lux.
  """

  @type model :: String.t()
  @type messages :: list(map())
  @type options :: keyword()
  @type response :: {:ok, map()} | {:error, term()}

  @callback complete(model(), messages(), options()) :: response()
  @callback cost_per_token(model()) :: {float(), float()}
end
