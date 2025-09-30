defmodule Lux.LLM.Ollama.ModelManager do
  @moduledoc """
  Tracks locally available Ollama models, ensures they are pulled when
  required, and periodically prunes stale cache entries. It keeps a very light
  ETS cache so repeated requests do not hit the Ollama daemon.
  """

  use GenServer

  alias Lux.LLM.Ollama.Client

  require Logger

  @type option :: {:cleanup_interval, non_neg_integer()}
  @type model_meta :: %{
          model: String.t(),
          digest: String.t() | nil,
          size: non_neg_integer() | nil,
          pulled_at: integer(),
          last_used_at: integer(),
          ttl: non_neg_integer()
        }

  @default_cleanup :timer.minutes(5)
  @default_ttl :timer.minutes(30)

  # -- Public API -----------------------------------------------------------------

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Ensure that a given model is available locally. When `auto_pull?` is true and
  the model is missing, the manager will trigger an `ollama pull` via the REST
  API.
  """
  @spec ensure_model(map()) :: :ok | {:error, term()}
  def ensure_model(%{model: model} = config) when is_binary(model) do
    GenServer.call(__MODULE__, {:ensure, config}, config[:pull_timeout] || 120_000)
  end

  @doc """
  Updates the `last_used_at` timestamp for a model. No-op if the model is not
  cached (for example when the request came from a different node).
  """
  @spec touch(String.t()) :: :ok
  def touch(model) when is_binary(model) do
    now = System.monotonic_time(:millisecond)

    with [{^model, meta}] <- :ets.lookup(__MODULE__, model) do
      :ets.insert(__MODULE__, {model, %{meta | last_used_at: now}})
    end

    :ok
  end

  @doc """
  Returns the cached meta-data for all models known to the cache.
  """
  @spec cached_models() :: [model_meta()]
  def cached_models do
    case :ets.info(__MODULE__) do
      :undefined -> []
      _info -> :ets.tab2list(__MODULE__) |> Enum.map(&elem(&1, 1))
    end
  end

  # -- GenServer callbacks ---------------------------------------------------------

  @impl true
  def init(opts) do
    table = :ets.new(__MODULE__, [:named_table, :set, :public, read_concurrency: true])
    cleanup_interval = Keyword.get(opts, :cleanup_interval, configured_cleanup())
    Process.send_after(self(), :cleanup, cleanup_interval)
    {:ok, %{table: table, cleanup_interval: cleanup_interval}}
  end

  @impl true
  def handle_call({:ensure, config}, _from, state) do
    case lookup(config, state) do
      {:ok, _meta} ->
        {:reply, :ok, state}

      :missing ->
        with {:ok, meta} <- fetch_or_pull(config) do
          insert(config.model, meta, config)
          {:reply, :ok, state}
        else
          {:error, reason} -> {:reply, {:error, reason}, state}
        end

      {:stale, meta} ->
        with {:ok, refreshed} <- fetch_or_pull(config) do
          insert(config.model, refreshed, config)
          {:reply, :ok, state}
        else
          {:error, reason} ->
            insert(config.model, %{meta | last_used_at: System.monotonic_time(:millisecond)}, config)
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_info(:cleanup, %{table: table, cleanup_interval: cleanup} = state) do
    now = System.monotonic_time(:millisecond)

    for {model, meta} <- :ets.tab2list(table) do
      if now - meta.last_used_at > meta.ttl do
        :ets.delete(table, model)
      end
    end

    Process.send_after(self(), :cleanup, cleanup)
    {:noreply, state}
  end

  # -- Helpers ---------------------------------------------------------------------

  defp lookup(%{model: model, model_ttl: ttl_override}, %{table: table}) do
    case :ets.lookup(table, model) do
      [{^model, meta}] ->
        ttl = ttl_override || meta.ttl || @default_ttl
        now = System.monotonic_time(:millisecond)

        if now - meta.last_used_at > ttl do
          {:stale, meta}
        else
          :ets.update_element(table, model, {5, now})
          {:ok, meta}
        end

      [] ->
        :missing
    end
  end

  defp fetch_or_pull(%{endpoint: endpoint, model: model} = config) do
    with {:ok, models} <- Client.list_models(endpoint, config),
         {:ok, meta} <- locate_model(models, model) do
      {:ok, meta}
    else
      {:error, reason} -> {:error, reason}
      :not_found -> maybe_pull(config)
    end
  end

  defp maybe_pull(%{auto_pull: false}), do: {:error, :model_missing}

  defp maybe_pull(%{endpoint: endpoint, model: model} = config) do
    Logger.info("Lux.LLM.Ollama pulling model #{model}")

    case Client.pull_model(endpoint, model, config) do
      {:ok, meta} -> {:ok, meta}
      {:error, reason} -> {:error, reason}
    end
  end

  defp locate_model(models, model) do
    case Enum.find(models, fn entry -> entry["name"] == model end) do
      nil -> :not_found
      %{"name" => ^model} = entry ->
        {:ok,
         %{
           model: model,
           digest: Map.get(entry, "digest"),
           size: Map.get(entry, "size"),
           pulled_at: System.monotonic_time(:millisecond),
           last_used_at: System.monotonic_time(:millisecond),
           ttl: Map.get(entry, "ttl", @default_ttl)
         }}
    end
  end

  defp insert(model, meta, %{model_ttl: ttl_override}) do
    ttl = ttl_override || meta.ttl || @default_ttl
    record = Map.put(meta, :ttl, ttl)
    :ets.insert(__MODULE__, {model, record})
    :ok
  end

  defp configured_cleanup do
    Application.get_env(:lux, Lux.LLM.Ollama, [])
    |> case do
      nil -> @default_cleanup
      keyword when is_list(keyword) -> Keyword.get(keyword, :cleanup_interval, @default_cleanup)
      map when is_map(map) -> Map.get(map, :cleanup_interval, @default_cleanup)
      other -> other
    end
    |> case do
      value when is_integer(value) and value > 0 -> value
      _ -> @default_cleanup
    end
  end
end
