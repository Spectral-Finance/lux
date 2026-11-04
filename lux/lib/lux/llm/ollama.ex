defmodule Lux.LLM.Ollama do
  @moduledoc """
  Local LLM implementation powered by Ollama (`Spectral-Finance/lux#96`).

  Supports:
  - Self-hosted chat completions with tool calling (`/api/chat`)
  - Local model management (`list_models/1`, `pull_model/2`, `delete_model/2`)
  - ETS model & response caching (`clear_cache/0`)
  - Hardware resource controls (`num_ctx`, `num_gpu`, `num_thread`, `keep_alive`)
  - Performance telemetry extraction (tokens/sec, load duration, eval duration)
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @default_base_url "http://localhost:11434"
  @cache_table :lux_ollama_cache

  defmodule Config do
    @moduledoc """
    Configuration struct for Ollama local inference and resource limits.
    """
    @type t :: %__MODULE__{
            base_url: String.t(),
            model: String.t(),
            temperature: float(),
            top_p: float(),
            num_ctx: pos_integer(),
            num_gpu: integer() | nil,
            num_thread: pos_integer() | nil,
            keep_alive: String.t(),
            stream: boolean(),
            cache: boolean(),
            messages: [map()]
          }

    defstruct base_url: "http://localhost:11434",
              model: "llama3.2",
              temperature: 0.7,
              top_p: 0.9,
              num_ctx: 4096,
              num_gpu: nil,
              num_thread: nil,
              keep_alive: "5m",
              stream: false,
              cache: false,
              messages: []
  end

  @doc """
  Ensures the ETS cache table for Ollama models and responses exists.
  """
  @spec ensure_cache() :: :ok
  def ensure_cache do
    case :ets.whereis(@cache_table) do
      :undefined ->
        try do
          :ets.new(@cache_table, [:named_table, :public, :set, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end

    :ok
  end

  @impl true
  def call(prompt, tools, config) when is_list(config) do
    call(prompt, tools, Map.new(config))
  end

  def call(prompt, tools, config) when is_map(config) do
    ensure_cache()
    config = struct(Config, config)
    cache_key = {:chat, config.model, prompt, config.temperature}

    if config.cache do
      case :ets.lookup(@cache_table, cache_key) do
        [{^cache_key, cached_signal}] ->
          {:ok, cached_signal}

        [] ->
          execute_chat(prompt, tools, config, cache_key)
      end
    else
      execute_chat(prompt, tools, config, cache_key)
    end
  end

  defp execute_chat(prompt, tools, config, cache_key) do
    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    options =
      %{
        temperature: config.temperature,
        top_p: config.top_p,
        num_ctx: config.num_ctx
      }
      |> maybe_put(:num_gpu, config.num_gpu)
      |> maybe_put(:num_thread, config.num_thread)

    body =
      %{
        model: config.model,
        messages: messages,
        stream: config.stream,
        keep_alive: config.keep_alive,
        options: options
      }
      |> maybe_add_tools(tools_config)

    [
      url: "#{config.base_url}/api/chat",
      json: body,
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        with {:ok, signal} <- handle_response(response, config) do
          if config.cache, do: :ets.insert(@cache_table, {cache_key, signal})
          {:ok, signal}
        end

      {:ok, %{status: status, body: %{"error" => error}}} ->
        {:error, {status, error}}

      {:error, error} ->
        Logger.error("Error calling Ollama API: #{inspect(error)}")
        {:error, "Failed to call local Ollama server"}
    end
  end

  @doc """
  Lists locally available Ollama models via `GET /api/tags`.
  """
  @spec list_models(keyword() | map()) :: {:ok, [map()]} | {:error, term()}
  def list_models(opts \\ %{}) do
    base_url = Map.get(Map.new(opts), :base_url, @default_base_url)

    [
      url: "#{base_url}/api/tags",
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, models}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, err} ->
        {:error, err}
    end
  end

  @doc """
  Downloads/pulls a model onto the local Ollama server via `POST /api/pull`.
  """
  @spec pull_model(String.t(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def pull_model(model_name, opts \\ %{}) when is_binary(model_name) do
    base_url = Map.get(Map.new(opts), :base_url, @default_base_url)

    [
      url: "#{base_url}/api/pull",
      json: %{name: model_name, stream: false},
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, err} -> {:error, err}
    end
  end

  @doc """
  Deletes a local model from Ollama via `DELETE /api/delete`.
  """
  @spec delete_model(String.t(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def delete_model(model_name, opts \\ %{}) when is_binary(model_name) do
    base_url = Map.get(Map.new(opts), :base_url, @default_base_url)

    [
      method: :delete,
      url: "#{base_url}/api/delete",
      json: %{name: model_name},
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status}} when status in 200..299 -> {:ok, %{deleted: model_name}}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, err} -> {:error, err}
    end
  end

  @doc """
  Clears all cached Ollama responses.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    ensure_cache()
    :ets.delete_all_objects(@cache_table)
    :ok
  end

  @doc """
  Computes tokens/sec and latency metrics from an Ollama response map.
  """
  @spec extract_performance_metrics(map()) :: map()
  def extract_performance_metrics(body) when is_map(body) do
    eval_count = Map.get(body, "eval_count", 0)
    eval_duration_ns = Map.get(body, "eval_duration", 0)
    total_duration_ns = Map.get(body, "total_duration", 0)

    tokens_per_sec =
      if eval_duration_ns > 0 do
        Float.round(eval_count / (eval_duration_ns / 1_000_000_000.0), 2)
      else
        0.0
      end

    %{
      prompt_tokens: Map.get(body, "prompt_eval_count", 0),
      completion_tokens: eval_count,
      total_duration_ms: div(total_duration_ns, 1_000_000),
      tokens_per_sec: tokens_per_sec
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp build_messages(prompt) when is_binary(prompt), do: [%{role: "user", content: prompt}]
  defp build_messages(messages) when is_list(messages), do: messages

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  @doc """
  Converts a Beam, Prism, or Lens into an Ollama function tool definition.
  """
  def tool_to_function(%Beam{module_name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_function(%Prism{module_name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_function(%Lens{module_name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: schema
      }
    }
  end

  defp handle_response(%{body: body}, config) when is_map(body) do
    message = Map.get(body, "message", %{})
    {:ok, content} = parse_content(message["content"])
    perf = extract_performance_metrics(body)

    payload = %{
      content: content,
      model: Map.get(body, "model", config.model),
      finish_reason: if(Map.get(body, "done", true), do: "stop", else: "length"),
      tool_calls: message["tool_calls"],
      tool_calls_results: nil
    }

    metadata = %{
      id: "ollama_#{System.unique_integer([:positive])}",
      created: Map.get(body, "created_at", DateTime.to_iso8601(DateTime.utc_now())),
      usage: perf
    }

    %{
      schema_id: ResponseSignal,
      payload: payload,
      metadata: metadata
    }
    |> Lux.Signal.new()
    |> ResponseSignal.validate()
  end

  defp parse_content(nil), do: {:ok, nil}

  defp parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:ok, %{"text" => content}}
    end
  end
end
