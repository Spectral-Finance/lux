defmodule Lux.LLM.Ollama.ModelManager do
  @moduledoc """
  Local model management, metadata caching, and telemetry tracking for Ollama.

  Provides functions to:
  - List installed local models (`/api/tags`)
  - List active in-memory models (`/api/ps`)
  - Inspect model details, Modelfile, template, and quantization (`/api/show`)
  - Pull models from the Ollama library (`/api/pull`)
  - Delete local models (`/api/delete`)
  - Ensure a model is available locally (`ensure_model/2`)
  - Cache model metadata and track inference performance metrics in ETS
  """

  @table :lux_ollama_model_cache
  @default_endpoint "http://localhost:11434"
  @default_ttl_ms 60_000

  @doc """
  Lists all locally available models via `GET /api/tags`.
  Uses an in-memory ETS cache unless `force_refresh: true` is passed.
  """
  @spec list_models(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_models(opts \\ []) do
    ensure_table()
    endpoint = Keyword.get(opts, :endpoint, default_endpoint())
    force_refresh = Keyword.get(opts, :force_refresh, false)
    ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
    cache_key = {:models, endpoint}

    case lookup_cache(cache_key, ttl_ms, force_refresh) do
      {:ok, cached} ->
        {:ok, cached}

      :miss ->
        req_opts =
          [
            method: :get,
            url: "#{String.trim_trailing(endpoint, "/")}/api/tags",
            headers: [{"accept", "application/json"}]
          ]
          |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

        case req_opts |> Req.new() |> Req.Request.run_request() do
          {_req, %Req.Response{status: 200, body: %{"models" => models}}} when is_list(models) ->
            put_cache(cache_key, models)
            {:ok, models}

          {_req, %Req.Response{status: status, body: body}} ->
            {:error, {:http_error, status, body}}

          {_req, error} ->
            {:error, error}
        end
    end
  end

  @doc """
  Lists currently loaded/running models and their VRAM usage via `GET /api/ps`.
  """
  @spec list_running(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_running(opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, default_endpoint())

    req_opts =
      [
        method: :get,
        url: "#{String.trim_trailing(endpoint, "/")}/api/ps",
        headers: [{"accept", "application/json"}]
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    case req_opts |> Req.new() |> Req.Request.run_request() do
      {_req, %Req.Response{status: 200, body: %{"models" => models}}} when is_list(models) ->
        {:ok, models}

      {_req, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {_req, error} ->
        {:error, error}
    end
  end

  @doc """
  Checks whether `model_name` is installed locally.
  """
  @spec model_available?(String.t(), keyword()) :: boolean()
  def model_available?(model_name, opts \\ []) when is_binary(model_name) do
    normalized_target = normalize_model_name(model_name)

    case list_models(opts) do
      {:ok, models} ->
        Enum.any?(models, fn m ->
          name = Map.get(m, "name") || Map.get(m, :name, "")
          normalize_model_name(name) == normalized_target or name == model_name
        end)

      {:error, _} ->
        false
    end
  end

  @doc """
  Ensures `model_name` is available locally, pulling it automatically if missing.
  """
  @spec ensure_model(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def ensure_model(model_name, opts \\ []) when is_binary(model_name) do
    if model_available?(model_name, opts) do
      {:ok, %{model: model_name, status: "available"}}
    else
      pull_model(model_name, opts)
    end
  end

  @doc """
  Pulls a model from the Ollama library via `POST /api/pull`.
  Invalidates the cached model list upon completion.
  """
  @spec pull_model(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def pull_model(model_name, opts \\ []) when is_binary(model_name) do
    ensure_table()
    endpoint = Keyword.get(opts, :endpoint, default_endpoint())
    insecure = Keyword.get(opts, :insecure, false)

    req_opts =
      [
        method: :post,
        url: "#{String.trim_trailing(endpoint, "/")}/api/pull",
        json: %{name: model_name, insecure: insecure, stream: false},
        headers: [{"content-type", "application/json"}],
        receive_timeout: Keyword.get(opts, :receive_timeout, 600_000)
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    case req_opts |> Req.new() |> Req.Request.run_request() do
      {_req, %Req.Response{status: 200, body: body}} ->
        invalidate_cache(endpoint)
        {:ok, if(is_map(body), do: Map.put_new(body, "model", model_name), else: %{"status" => body})}

      {_req, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {_req, error} ->
        {:error, error}
    end
  end

  @doc """
  Shows detailed metadata for a local model via `POST /api/show`.
  """
  @spec show_model(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def show_model(model_name, opts \\ []) when is_binary(model_name) do
    ensure_table()
    endpoint = Keyword.get(opts, :endpoint, default_endpoint())
    cache_key = {:model_info, endpoint, model_name}
    ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
    force_refresh = Keyword.get(opts, :force_refresh, false)

    case lookup_cache(cache_key, ttl_ms, force_refresh) do
      {:ok, info} ->
        {:ok, info}

      :miss ->
        req_opts =
          [
            method: :post,
            url: "#{String.trim_trailing(endpoint, "/")}/api/show",
            json: %{name: model_name},
            headers: [{"content-type", "application/json"}]
          ]
          |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

        case req_opts |> Req.new() |> Req.Request.run_request() do
          {_req, %Req.Response{status: 200, body: body}} when is_map(body) ->
            put_cache(cache_key, body)
            {:ok, body}

          {_req, %Req.Response{status: status, body: body}} ->
            {:error, {:http_error, status, body}}

          {_req, error} ->
            {:error, error}
        end
    end
  end

  @doc """
  Deletes a local model via `DELETE /api/delete`.
  """
  @spec delete_model(String.t(), keyword()) :: :ok | {:error, term()}
  def delete_model(model_name, opts \\ []) when is_binary(model_name) do
    ensure_table()
    endpoint = Keyword.get(opts, :endpoint, default_endpoint())

    req_opts =
      [
        method: :delete,
        url: "#{String.trim_trailing(endpoint, "/")}/api/delete",
        json: %{name: model_name},
        headers: [{"content-type", "application/json"}]
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    case req_opts |> Req.new() |> Req.Request.run_request() do
      {_req, %Req.Response{status: 200}} ->
        invalidate_cache(endpoint)
        :ets.delete(@table, {:model_info, endpoint, model_name})
        :ok

      {_req, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {_req, error} ->
        {:error, error}
    end
  end

  @doc """
  Records inference performance metrics for `model_name` in ETS.
  """
  @spec record_metrics(String.t(), map()) :: :ok
  def record_metrics(model_name, metrics) when is_binary(model_name) and is_map(metrics) do
    ensure_table()
    key = {:metrics, model_name}

    existing =
      case :ets.lookup(@table, key) do
        [{^key, stats}] -> stats
        [] -> %{calls: 0, total_tokens: 0, avg_tokens_per_second: 0.0, last_metrics: %{}}
      end

    calls = existing.calls + 1
    eval_tokens = Map.get(metrics, :eval_count, 0) + Map.get(metrics, :prompt_eval_count, 0)
    tps = Map.get(metrics, :tokens_per_second, 0.0)

    avg_tps =
      if calls == 1 do
        tps
      else
        Float.round((existing.avg_tokens_per_second * existing.calls + tps) / calls, 2)
      end

    updated = %{
      calls: calls,
      total_tokens: existing.total_tokens + eval_tokens,
      avg_tokens_per_second: avg_tps,
      last_metrics: metrics
    }

    :ets.insert(@table, {key, updated})
    :ok
  end

  @doc """
  Retrieves aggregated performance metrics for `model_name`.
  """
  @spec get_metrics(String.t()) :: map()
  def get_metrics(model_name) when is_binary(model_name) do
    ensure_table()
    key = {:metrics, model_name}

    case :ets.lookup(@table, key) do
      [{^key, stats}] -> stats
      [] -> %{calls: 0, total_tokens: 0, avg_tokens_per_second: 0.0, last_metrics: %{}}
    end
  end

  @doc """
  Clears all cached model lists and metadata.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    ensure_table()
    :ets.delete_all_objects(@table)
    :ok
  end

  defp invalidate_cache(endpoint) do
    ensure_table()
    :ets.delete(@table, {:models, endpoint})
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
        rescue
          ArgumentError -> @table
        end

      _tid ->
        @table
    end
  end

  defp lookup_cache(_key, _ttl_ms, true), do: :miss

  defp lookup_cache(key, ttl_ms, false) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, {value, inserted_at}}] when now - inserted_at <= ttl_ms ->
        {:ok, value}

      _ ->
        :miss
    end
  end

  defp put_cache(key, value) do
    :ets.insert(@table, {key, {value, System.monotonic_time(:millisecond)}})
  end

  defp normalize_model_name(name) do
    case String.split(name, ":") do
      [base] -> "#{base}:latest"
      [base, tag] -> "#{base}:#{tag}"
      _ -> name
    end
  end

  defp default_endpoint do
    Application.get_env(:lux, :ollama_config, %{})[:endpoint] ||
      System.get_env("OLLAMA_ENDPOINT", @default_endpoint)
  end
end
