defmodule Lux.LLM.ProviderRegistry do
  @moduledoc """
  Registry for LLM providers.

  The registry reads the list of providers from the application environment:

      config :lux,
        llm_providers: [
          {:anthropic, Lux.LLM.AnthropicProvider},
          {:openai,    Lux.LLM.OpenAIProvider}
        ]

  It stores a map of provider name → module and offers lookup helpers.
  """

  use GenServer

  @type provider :: module()
  @type state :: %{
          providers: %{optional(atom()) => provider()},
          order: [atom()]
        }

  ## Public API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec get_provider(atom()) :: provider() | nil
  def get_provider(name) when is_atom(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  @spec list_providers() :: [provider()]
  def list_providers do
    GenServer.call(__MODULE__, :list)
  end

  ## GenServer callbacks

  @impl true
  def init(_) do
    providers = load_providers()
    order = Map.keys(providers)

    {:ok, %{providers: providers, order: order}}
  end

  @impl true
  def handle_call({:get, name}, _from, %{providers: providers} = state) do
    {:reply, Map.get(providers, name), state}
  end

  def handle_call(:list, _from, %{providers: providers} = state) do
    {:reply, Map.values(providers), state}
  end

  ## Helpers

  defp load_providers do
    Application.get_env(:lux, :llm_providers, [])
    |> Enum.into(%{}, fn {name, mod} -> {name, mod} end)
  end
end
