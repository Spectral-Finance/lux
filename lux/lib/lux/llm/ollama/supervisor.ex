defmodule Lux.LLM.Ollama.Supervisor do
  @moduledoc """
  Supervises the supporting processes needed for the Ollama integration
  (resource pool + model cache manager).
  """

  use Supervisor

  alias Lux.LLM.Ollama
  alias Lux.LLM.Ollama.{ModelManager, ResourcePool}

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    defaults = Ollama.defaults()
    env = Application.get_env(:lux, Ollama, [])

    max_concurrency = Keyword.get(env, :max_concurrency, defaults[:max_concurrency])
    cleanup_interval = Keyword.get(env, :cleanup_interval, defaults[:cleanup_interval])

    children = [
      {ResourcePool, size: resolve(max_concurrency)},
      {ModelManager, cleanup_interval: resolve(cleanup_interval)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp resolve({:runtime_config, _, _, _} = runtime), do: Lux.Config.resolve(runtime)
  defp resolve(value), do: value
end
