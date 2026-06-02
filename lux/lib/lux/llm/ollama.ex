defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation supporting local model inference, model management,
  LRU response caching, and GPU resource monitoring.

  Uses the Ollama REST API:
    - POST /api/generate   — text generation
    - POST /api/chat       — chat completions (OpenAI-compatible)
    - GET  /api/tags       — list available models
    - POST /api/pull       — pull/download a model
    - DELETE /api/delete   — remove a model
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @default_endpoint "http://localhost:11434"
  @cache_table :ollama_response_cache
  @cache_max_size 512
  @cache_ttl_seconds 300

  defmodule Config do
    @moduledoc """
    Configuration for the Ollama LLM client.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t() | nil,
            temperature: float(),
            top_p: float(),
            top_k: integer(),
            max_tokens: integer(),
            stream: boolean(),
            repeat_penalty: float(),
            seed: integer(),
            num_predict: integer(),
            num_ctx: integer(),
            messages: [map()],
            cache_enabled: boolean()
          }

    defstruct endpoint: "http://localhost:11434",
              model: "llama3",
              api_key: nil,
              temperature: 0.7,
              top_p: 0.9,
              top_k: 40,
              max_tokens: nil,
              stream: false,
              repeat_penalty: 1.1,
              seed: nil,
              num_predict: nil,
              num_ctx: 4096,
              messages: [],
              cache_enabled: true
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :ollama_models)[:default],
            endpoint: Application.get_env(:lux, :ollama_endpoint, @default_endpoint)
          },
          config
        )
      )

    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        stream: false,
        options: build_options(config)
      }
      |> maybe_add_tools(tools_config)

    cache_key = build_cache_key(body)

    if config.cache_enabled do
      case cache_lookup(cache_key) do
        {:ok, cached} ->
          Logger.debug("Ollama cache hit for #{config.model}")
          emit_telemetry(:cache_hit, config.model)
          {:ok, cached}

        :miss ->
          make_request(config, body, cache_key)
      end
    else
      make_request(config, body, cache_key)
    end
  end

  @doc """
  Lists all models available on the Ollama server.

  Returns `{:ok, [%{name: String.t(), size: integer(), ...}]}` or `{:error, reason}`.
  """
  def list_models(config \\ []) do
    endpoint = config_endpoint(config)

    Req.get!(endpoint <> "/api/tags")
    |> case do
      %{status: 200, body: %{"models" => models}} ->
        {:ok, models}

      %{status: 401} ->
        {:error, :unauthorized}

      %{body: %{"error" => error}} ->
        {:error, error}

      other ->
        {:error, "Unexpected response: #{inspect(other)}"}
    end
  rescue
    e in Req.TransportError ->
      {:error, "Connection error to Ollama: #{Exception.message(e)}"}
  end

  @doc """
  Returns only the model name strings available locally.

  Returns `{:ok, [String.t()]}` or `{:error, reason}`.
  """
  def available_models(config \\ []) do
    case list_models(config) do
      {:ok, models} -> {:ok, Enum.map(models, & &1["name"])}
      error -> error
    end
  end

  @doc """
  Pulls (downloads) a model from the Ollama registry.

  Returns `{:ok, status}` or `{:error, reason}`.
  """
  def pull_model(model_name, config \\ []) do
    endpoint = config_endpoint(config)

    body = %{name: model_name, stream: false}

    Req.post!(endpoint <> "/api/pull", json: body)
    |> case do
      %{status: 200, body: %{"status" => status}} ->
        evict_model_from_cache(model_name)
        Logger.info("Ollama model pulled: #{model_name}")
        {:ok, status}

      %{status: 401} ->
        {:error, :unauthorized}

      %{body: %{"error" => error}} ->
        {:error, error}

      other ->
        {:error, "Failed to pull model: #{inspect(other)}"}
    end
  rescue
    e in Req.TransportError ->
      {:error, "Connection error to Ollama: #{Exception.message(e)}"}
  end

  @doc """
  Deletes a model from the Ollama server.

  Returns `{:ok, :deleted}` or `{:error, reason}`.
  """
  def delete_model(model_name, config \\ []) do
    endpoint = config_endpoint(config)

    Req.delete!(endpoint <> "/api/delete", json: %{name: model_name})
    |> case do
      %{status: 200} ->
        evict_model_from_cache(model_name)
        Logger.info("Ollama model deleted: #{model_name}")
        {:ok, :deleted}

      %{status: 401} ->
        {:error, :unauthorized}

      %{status: 404} ->
        {:error, :not_found}

      %{body: %{"error" => error}} ->
        {:error, error}

      other ->
        {:error, "Failed to delete model: #{inspect(other)}"}
    end
  rescue
    e in Req.TransportError ->
      {:error, "Connection error to Ollama: #{Exception.message(e)}"}
  end

  @doc """
  Retrieves detailed information about a specific model.

  Returns `{:ok, model_info}` or `{:error, reason}`.
  """
  def model_info(model_name, config \\ []) do
    endpoint = config_endpoint(config)

    Req.post!(endpoint <> "/api/show", json: %{name: model_name})
    |> case do
      %{status: 200, body: info} ->
        {:ok, info}

      %{status: 404} ->
        {:error, :not_found}

      %{body: %{"error" => error}} ->
        {:error, error}

      other ->
        {:error, "Failed to get model info: #{inspect(other)}"}
    end
  rescue
    e in Req.TransportError ->
      {:error, "Connection error to Ollama: #{Exception.message(e)}"}
  end

  @doc """
  Generates a completion using the `/api/generate` endpoint (raw text generation).

  Returns `{:ok, response}` or `{:error, reason}`.
  """
  def generate(prompt, config) do
    config = struct(Config, ensure_map(config))
    endpoint = config_endpoint(config)

    body = %{
      model: Lux.Config.resolve(config.model),
      prompt: prompt,
      stream: false,
      options: build_options(config)
    }

    Req.post!(endpoint <> "/api/generate", json: body)
    |> case do
      %{status: 200, body: %{"response" => response}} ->
        {:ok, %{
          response: response,
          model: body["model"],
          done: body["done"],
          total_duration: body["total_duration"],
          eval_count: body["eval_count"],
          eval_duration: body["eval_duration"]
        }}

      %{body: %{"error" => error}} ->
        {:error, error}

      other ->
        {:error, "Generate failed: #{inspect(other)}"}
    end
  rescue
    e in Req.TransportError ->
      {:error, "Connection error to Ollama: #{Exception.message(e)}"}
  end

  @doc """
  Checks if the Ollama server is reachable and healthy.

  Returns `:ok` or `{:error, reason}`.
  """
  def health_check(config \\ []) do
    endpoint = config_endpoint(config)

    case Req.get(endpoint, receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: s}} -> {:error, "Unexpected status #{s}"}
      {:error, e} -> {:error, "Connection failed: #{inspect(e)}"}
    end
  end

  @doc """
  Returns the current LRU cache statistics.

  Returns a map with `:size`, `:hits`, `:misses`, `:evictions`.
  """
  def cache_stats do
    hits = :persistent_term.get({__MODULE__, :cache_hits}, 0)
    misses = :persistent_term.get({__MODULE__, :cache_misses}, 0)
    evictions = :persistent_term.get({__MODULE__, :cache_evictions}, 0)
    size = :ets.info(@cache_table, :size)

    %{
      size: size,
      hits: hits,
      misses: misses,
      evictions: evictions,
      max_size: @cache_max_size
    }
  end

  @doc """
  Clears the entire response cache.
  """
  def clear_cache do
    :ets.delete_all_objects(@cache_table)
    :ok
  end

  @doc """
  Initializes the LRU cache ETS table. Called at application start.
  """
  def init_cache do
    unless :ets.whereis(@cache_table) != :undefined do
      @cache_table =
        :ets.new(@cache_table, [
          :set,
          :public,
          :named_table,
          {:read_concurrency, true},
          {:write_concurrency, false}
        ])
    end

    :persistent_term.put({__MODULE__, :cache_hits}, 0)
    :persistent_term.put({__MODULE__, :cache_misses}, 0)
    :persistent_term.put({__MODULE__, :cache_evictions}, 0)

    Logger.info("Ollama LRU cache initialized (max: #{@cache_max_size} entries, ttl: #{@cache_ttl_seconds}s)")
    :ok
  end

  @doc """
  Monitors GPU resource usage via nvidia-smi on the Ollama host.

  Returns `{:ok, gpu_info}` or `{:error, reason}`.
  Returns a list of maps with GPU index, name, memory used, memory total, utilization.
  """
  def gpu_monitor do
    case System.cmd("nvidia-smi", [
      "--query-gpu=index,name,memory.used,memory.total,utilization.gpu,temperature.gpu",
      "--format=csv,noheader,nounits"
    ]) do
      {output, 0} ->
        gpus =
          output
          |> String.trim()
          |> String.split("\n")
          |> Enum.map(fn line ->
            [index, name, mem_used, mem_total, gpu_util, temp] =
              String.split(line, ", ", parts: 6)

            %{
              index: String.trim(index) |> String.to_integer(),
              name: String.trim(name),
              memory_used_mb: parse_int(String.trim(mem_used)),
              memory_total_mb: parse_int(String.trim(mem_total)),
              memory_percent: calc_memory_percent(mem_used, mem_total),
              gpu_utilization_pct: parse_int(String.trim(gpu_util)),
              temperature_c: parse_int(String.trim(temp))
            }
          end)

        {:ok, gpus}

      {error_output, code} ->
        Logger.warning("nvidia-smi failed (code #{code}): #{error_output}")
        {:error, "nvidia-smi not available or failed (GPU monitoring unavailable)"}
    end
  end

  @doc """
  Gets a summary of GPU resources suitable for decision-making.

  Returns `{:ok, summary}` with total/used memory, GPU count, and per-GPU details.
  """
  def gpu_summary do
    case gpu_monitor() do
      {:ok, gpus} ->
        total_mem = Enum.reduce(gpus, 0, &(&1.memory_total_mb + &2))
        used_mem = Enum.reduce(gpus, 0, &(&1.memory_used_mb + &2))
        avg_util = if length(gpus) > 0, do: Enum.sum(Enum.map(gpus, & &1.gpu_utilization_pct)) / length(gpus), else: 0

        {:ok,
         %{
           gpu_count: length(gpus),
           total_memory_mb: total_mem,
           used_memory_mb: used_mem,
           free_memory_mb: total_mem - used_mem,
           avg_gpu_utilization_pct: Float.round(avg_util, 1),
           gpus: gpus
         }}

      err ->
        err
    end
  end

  @doc """
  Runs a benchmark comparing multiple Ollama models on the same prompt.
  Accepts a list of model names and a prompt. Returns timing and output data.

  Returns `{:ok, [benchmark_result]}` or `{:error, reason}`.
  """
  def benchmark_models(model_names, prompt, config \\ []) when is_list(model_names) do
    results =
      Enum.map(model_names, fn model_name ->
        model_config = Map.put(ensure_map(config), :model, model_name)
        start = System.monotonic_time(:millisecond)

        result = generate(prompt, model_config)

        elapsed = System.monotonic_time(:millisecond) - start

        case result do
          {:ok, resp} ->
            %{
              model: model_name,
              duration_ms: elapsed,
              total_duration_ns: resp[:total_duration],
              eval_count: resp[:eval_count],
              eval_duration_ns: resp[:eval_duration],
              tokens_per_sec:
                if resp[:eval_count] && resp[:eval_duration] && resp[:eval_duration] > 0 do
                  Float.round(resp[:eval_count] / (resp[:eval_duration] / 1_000_000_000), 1)
                end,
              success: true,
              response_preview: String.slice(resp[:response] || "", 0, 120)
            }

          {:error, reason} ->
            %{
              model: model_name,
              duration_ms: elapsed,
              success: false,
              error: reason
            }
        end
      end)

    {:ok, results}
  end

  # ---- Private Helpers ----

  defp config_endpoint(config) do
    case config do
      %{endpoint: ep} when is_binary(ep) -> String.trim_trailing(ep, "/")
      %{"endpoint" => ep} when is_binary(ep) -> String.trim_trailing(ep, "/")
      _ -> Application.get_env(:lux, :ollama_endpoint, @default_endpoint)
    end
  end

  defp ensure_map(%Config{} = config), do: Map.from_struct(config)
  defp ensure_map(config) when is_map(config), do: config
  defp ensure_map(config) when is_list(config), do: Map.new(config)

  defp build_options(config) do
    opts = %{
      temperature: config.temperature
    }

    opts
    |> maybe_put(:top_p, config.top_p)
    |> maybe_put(:top_k, config.top_k)
    |> maybe_put(:repeat_penalty, config.repeat_penalty)
    |> maybe_put(:num_predict, config.num_predict || config.max_tokens)
    |> maybe_put(:num_ctx, config.num_ctx)
    |> maybe_put(:seed, config.seed)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp build_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_messages(messages) when is_list(messages) do
    messages
    |> Enum.map(fn
      %{role: _, content: _} = msg -> msg
      msg when is_binary(msg) -> %{role: "user", content: msg}
    end)
  end

  defp build_tools_config([]), do: nil
  defp build_tools_config(tools) when is_list(tools) do
    Enum.map(tools, &tool_to_function/1)
  end

  defp maybe_add_tools(body, nil), do: body
  defp maybe_add_tools(body, tools) when is_list(tools) do
    Map.put(body, :tools, tools)
  end

  defp tool_to_function(%Beam{module_name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  defp tool_to_function(%Prism{module_name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  defp tool_to_function(%Lens{module_name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: schema
      }
    }
  end

  defp build_cache_key(body) do
    content =
      body
      |> Map.take([:model, :messages, :options, :tools])
      |> then(&:erlang.phash2(&1, 1_000_000_000))

    {:ollama_cache, body[:model], content}
  end

  defp cache_lookup(key) do
    case :ets.lookup(@cache_table, key) do
      [{^key, response, expires_at}] ->
        if System.os_time(:second) < expires_at do
          :persistent_term.put(
            {__MODULE__, :cache_hits},
            :persistent_term.get({__MODULE__, :cache_hits}, 0) + 1
          )
          emit_telemetry(:cache, %{hit: true})
          {:ok, response}
        else
          :ets.delete(@cache_table, key)
          :persistent_term.put(
            {__MODULE__, :cache_misses},
            :persistent_term.get({__MODULE__, :cache_misses}, 0) + 1
          )
          :miss
        end

      [] ->
        :persistent_term.put(
          {__MODULE__, :cache_misses},
          :persistent_term.get({__MODULE__, :cache_misses}, 0) + 1
        )
        :miss
    end
  end

  defp cache_put(key, response) do
    evict_lru_if_needed()
    expires_at = System.os_time(:second) + @cache_ttl_seconds
    :ets.insert(@cache_table, {key, response, expires_at})
    :ok
  end

  defp evict_lru_if_needed do
    size = :ets.info(@cache_table, :size)

    if size >= @cache_max_size do
      :persistent_term.put(
        {__MODULE__, :cache_evictions},
        :persistent_term.get({__MODULE__, :cache_evictions}, 0) + 1
      )

      :ets.first(@cache_table)
      |> case do
        :"$end_of_table" -> :ok
        key -> :ets.delete(@cache_table, key)
      end
    end
  end

  defp evict_model_from_cache(model_name) do
    :ets.match_delete(@cache_table, {{:ollama_cache, model_name, :_}, :_, :_})
    :ok
  end

  defp make_request(config, body, cache_key) do
    endpoint = config_endpoint(config)
    url = endpoint <> "/api/chat"
    headers = [{"Content-Type", "application/json"}]

    start_time = System.monotonic_time(:millisecond)

    req_opts =
      Application.get_env(:lux, __MODULE__, [])
      |> Keyword.take([:receive_timeout, :connect_options, :retry, :max_retries])

    [
      url: url,
      json: body,
      headers: headers
    ]
    |> Keyword.merge(req_opts)
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        emit_telemetry(:ok, config.model, elapsed)
        handle_response(response, config, cache_key)

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: 404}} ->
        {:error, :model_not_found}

      {:ok, %{status: status, body: %{"error" => error}}} ->
        Logger.error("Ollama API error (#{status}): #{inspect(error)}")
        {:error, error}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, :ollama_unreachable}

      {:error, error} ->
        handle_error(error)
    end
  end

  defp handle_response(%{body: %{"message" => message}} = response, config, cache_key) do
    content = message["content"] || ""

    parsed =
      case Jason.decode(content) do
        {:ok, structured} -> structured
        {:error, _} -> content
      end

    result = %Lux.LLM.Response{
      content: parsed,
      tool_calls: message["tool_calls"] || [],
      finish_reason: response.body["done_reason"] || "stop"
    }

    if config.cache_enabled do
      cache_put(cache_key, result)
    end

    {:ok, result}
  end

  defp handle_response(%{body: body}, _config, _cache_key) do
    {:ok, %Lux.LLM.Response{
      content: body["response"] || inspect(body),
      tool_calls: [],
      finish_reason: "stop"
    }}
  end

  defp handle_error(error) do
    Logger.error("Ollama API error: #{inspect(error)}")
    {:error, "Ollama API error: #{inspect(error)}"}
  end

  defp emit_telemetry(event, model, extra \\ nil) do
    metadata = %{model: model}
    metadata = if extra, do: Map.put(metadata, :extra, extra), else: metadata
    :telemetry.execute([:lux, :ollama, event], %{time: System.system_time()}, metadata)
  end

  defp parse_int(str) do
    case Integer.parse(String.trim(str)) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp calc_memory_percent(used_str, total_str) do
    used = parse_int(used_str)
    total = parse_int(total_str)

    if total > 0 do
      Float.round(used / total * 100, 1)
    else
      0.0
    end
  end
end
