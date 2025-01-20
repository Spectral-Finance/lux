defmodule Lux.LLM do
  @moduledoc """
  Behaviour for LLM implementations.
  """

  @callback call(prompt :: String.t(), tools :: list(), opts :: keyword()) ::
              {:ok, Lux.Signal.t()} | {:error, String.t()}

  def call(prompt, tools \\ [], opts \\ []) do
    impl = Application.get_env(:lux, [__MODULE__, :default_module])
    impl.call(prompt, tools, opts)
  end
end
