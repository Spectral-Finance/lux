defmodule Lux.LLM do
  @moduledoc """
  Universal LLM provider abstraction layer.
  """

  defmodule Provider do
    @callback chat(messages :: list(), opts :: map()) :: {:ok, map()} | {:error, term()}
    @callback name() :: atom()
  end

  def chat(messages, opts \\ %{}) do
    Lux.LLM.Client.chat(messages, opts)
  end
end

defmodule Lux.LLM.Client do
  require Logger

  def chat(messages, opts) do
    providers = Lux.LLM.Registry.get_providers()
    try_providers(providers, messages, opts)
  end

  defp try_providers([], _messages, _opts), do: {:error, :no_providers_available}
  defp try_providers([provider | rest], messages, opts) do
    case provider.chat(messages, opts) do
      {:ok, response} -> {:ok, response}
      {:error, reason} ->
        Logger.warning("LLM Provider #{provider.name()} failed: #{inspect(reason)}. Falling back...")
        try_providers(rest, messages, opts)
    end
  end
end

defmodule Lux.LLM.Registry do
  use Agent

  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)

  def register(provider), do: Agent.update(__MODULE__, &[provider | &1])

  def get_providers, do: Agent.get(__MODULE__, & &1)
end