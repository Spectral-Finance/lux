defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation for local, self-hosted models.

  The provider keeps local model operations explicit: chat calls use `/api/chat`,
  model management uses Ollama's tags/show/pull/delete endpoints, and
  `ensure_model/2` uses a short-lived in-memory cache to avoid listing models for
  every local request.
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @default_endpoint "http://localhost:11434"
  @default_model "llama3.2"
  @model_cache_key {__MODULE__, :models}
  @resource_option_keys [
    :temperature,
    :top_p,
    :top_k,
    :repeat_penalty,
    :seed,
    :num_ctx,
    :num_predict,
    :num_gpu,
    :num_thread,
    :stop
  ]

  defmodule Config do
    @moduledoc """
    Configuration for the local Ollama provider.
    """

    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            temperature: float(),
            top_p: float() | nil,
            top_k: integer() | nil,
            repeat_penalty: float() | nil,
            seed: integer() | nil,
            num_ctx: integer() | nil,
            num_predict: integer() | nil,
            num_gpu: integer() | nil,
            num_thread: integer() | nil,
            stop: [String.t()],
            keep_alive: String.t() | integer() | nil,
            stream: boolean(),
            format: String.t() | map() | nil,
            messages: [map()],
            receive_timeout: integer(),
            cache_ttl_ms: integer()
          }

    defstruct endpoint: "http://localhost:11434",
              model: "llama3.2",
              temperature: 0.7,
              top_p: nil,
              top_k: nil,
              repeat_penalty: nil,
              seed: nil,
              num_ctx: nil,
              num_predict: nil,
              num_gpu: nil,
              num_thread: nil,
              stop: [],
              keep_alive: "5m",
              stream: false,
              format: nil,
              messages: [],
              receive_timeout: 120_000,
              cache_ttl_ms: 60_000
  end

  @impl true
  def call(prompt, tools, config) do
    config = normalize_config(config)
    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        stream: config.stream,
        options: resource_options(config)
      }
      |> maybe_put(:keep_alive, config.keep_alive)
      |> maybe_put(:format, config.format)
      |> maybe_add_tools(tools_config)

    case post_json(config, "/api/chat", body) do
      {:ok, %{status: 200} = response} ->
        handle_chat_response(response)

      {:ok, %{status: 404, body: %{"error" => message}}} ->
        {:error, {:model_not_found, message}}

      {:ok, %{status: status, body: %{"error" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Lists locally available Ollama models.
  """
  @spec list_models(map() | keyword() | Config.t()) :: {:ok, [map()]} | {:error, term()}
  def list_models(config \\ %{}) do
    config = normalize_config(config)

    case get(config, "/api/tags") do
      {:ok, %{status: 200, body: %{"models" => models}}} when is_list(models) ->
        {:ok, Enum.map(models, &normalize_model/1)}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Reads Ollama metadata for a model.
  """
  @spec show_model(String.t(), map() | keyword() | Config.t()) :: {:ok, map()} | {:error, term()}
  def show_model(model, config \\ %{}) do
    config = normalize_config(config)

    case post_json(config, "/api/show", %{model: model}) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, error} -> handle_error(error)
    end
  end

  @doc """
  Pulls a model with streaming disabled so callers receive one final response.
  """
  @spec pull_model(String.t(), map() | keyword() | Config.t()) :: {:ok, map()} | {:error, term()}
  def pull_model(model, config \\ %{}) do
    config = normalize_config(config)

    case post_json(config, "/api/pull", %{model: model, stream: false}) do
      {:ok, %{status: 200, body: body}} ->
        clear_model_cache()
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Deletes a local model and clears the provider model cache.
  """
  @spec delete_model(String.t(), map() | keyword() | Config.t()) ::
          {:ok, map()} | {:error, term()}
  def delete_model(model, config \\ %{}) do
    config = normalize_config(config)

    case delete_json(config, "/api/delete", %{model: model}) do
      {:ok, %{status: status}} when status in [200, 204] ->
        clear_model_cache()
        {:ok, %{deleted: model}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Ensures a model is locally available, pulling it when the cached model list does
  not include it.
  """
  @spec ensure_model(String.t(), map() | keyword() | Config.t()) ::
          {:ok, map()} | {:error, term()}
  def ensure_model(model, config \\ %{}) do
    config = normalize_config(config)

    with {:ok, models, source} <- cached_models(config) do
      if Enum.any?(models, &(&1.name == model)) do
        {:ok, %{model: model, status: :available, source: source}}
      else
        with {:ok, pull} <- pull_model(model, config) do
          {:ok, %{model: model, status: :pulled, source: :remote, pull: pull}}
        end
      end
    end
  end

  @doc """
  Returns cached model tags when fresh, otherwise refreshes from Ollama.
  """
  @spec cached_models(map() | keyword() | Config.t()) ::
          {:ok, [map()], :cache_hit | :refreshed} | {:error, term()}
  def cached_models(config \\ %{}) do
    config = normalize_config(config)
    cache = :persistent_term.get(@model_cache_key, %{})
    endpoint = normalize_endpoint(config.endpoint)
    now = System.monotonic_time(:millisecond)

    case Map.get(cache, endpoint) do
      %{models: models, cached_at: cached_at} when now - cached_at <= config.cache_ttl_ms ->
        {:ok, models, :cache_hit}

      _ ->
        with {:ok, models} <- list_models(config) do
          :persistent_term.put(
            @model_cache_key,
            Map.put(cache, endpoint, %{models: models, cached_at: now})
          )

          {:ok, models, :refreshed}
        end
    end
  end

  @doc """
  Clears the in-memory model list cache.
  """
  @spec clear_model_cache() :: :ok
  def clear_model_cache do
    try do
      :persistent_term.erase(@model_cache_key)
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  @doc """
  Builds the Ollama `options` map and resource warnings for a config.
  """
  @spec resource_plan(map() | keyword() | Config.t()) :: map()
  def resource_plan(config \\ %{}) do
    config = normalize_config(config)
    options = resource_options(config)

    %{
      endpoint: normalize_endpoint(config.endpoint),
      model: Lux.Config.resolve(config.model),
      keep_alive: config.keep_alive,
      stream: config.stream,
      options: options,
      warnings: resource_warnings(options)
    }
  end

  @doc """
  Normalizes Ollama duration and token-count fields into monitoring metrics.
  """
  @spec performance_summary(map()) :: map()
  def performance_summary(body) when is_map(body) do
    eval_count = fetch_value(body, "eval_count")
    eval_duration = fetch_value(body, "eval_duration")

    %{
      total_duration_ms: duration_ms(fetch_value(body, "total_duration")),
      load_duration_ms: duration_ms(fetch_value(body, "load_duration")),
      prompt_eval_duration_ms: duration_ms(fetch_value(body, "prompt_eval_duration")),
      eval_duration_ms: duration_ms(eval_duration),
      prompt_eval_count: fetch_value(body, "prompt_eval_count"),
      eval_count: eval_count,
      tokens_per_second: tokens_per_second(eval_count, eval_duration)
    }
  end

  def tool_to_function({:python, path}) do
    path
    |> Prism.view()
    |> tool_to_function()
  end

  def tool_to_function(tool_module) when is_atom(tool_module) and not is_nil(tool_module) do
    cond do
      Lux.prism?(tool_module) -> tool_to_function(tool_module.view())
      Lux.beam?(tool_module) -> tool_to_function(tool_module.view())
      Lux.lens?(tool_module) -> tool_to_function(tool_module.view())
      true -> raise "Unsupported tool type: #{inspect(tool_module)}"
    end
  end

  def tool_to_function(%Beam{
        module_name: name,
        description: description,
        input_schema: input_schema
      }) do
    function_tool(name, description, input_schema)
  end

  def tool_to_function(%Prism{
        module_name: name,
        description: description,
        input_schema: input_schema
      }) do
    function_tool(name, description, input_schema)
  end

  def tool_to_function(%Lens{module_name: name, description: description, schema: schema}) do
    function_tool(name, description, schema)
  end

  defp function_tool(name, description, parameters) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: parameters || %{type: :object, properties: %{}}
      }
    }
  end

  defp normalize_config(%Config{} = config), do: config

  defp normalize_config(config) do
    ollama_config = Application.get_env(:lux, :ollama, [])
    ollama_models = Application.get_env(:lux, :ollama_models, [])

    defaults = %{
      endpoint: Keyword.get(ollama_config, :endpoint, @default_endpoint),
      model: Keyword.get(ollama_models, :default, @default_model)
    }

    struct(Config, Map.merge(defaults, Map.new(config)))
  end

  defp build_messages(prompt), do: [%{role: "user", content: prompt}]

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  defp resource_options(config) do
    @resource_option_keys
    |> Enum.reduce(%{}, fn key, acc ->
      value = Map.get(config, key)
      if value in [nil, []], do: acc, else: Map.put(acc, key, value)
    end)
  end

  defp resource_warnings(options) do
    []
    |> maybe_warn(
      Map.get(options, :num_ctx, 0) > 32_768,
      "num_ctx is high; local memory pressure likely"
    )
    |> maybe_warn(
      Map.get(options, :num_predict, 0) > 8_192,
      "num_predict is high; long generations can monopolize local compute"
    )
    |> maybe_warn(
      Map.get(options, :num_thread, 0) > System.schedulers_online(),
      "num_thread exceeds schedulers_online"
    )
  end

  defp maybe_warn(warnings, true, message), do: [message | warnings]
  defp maybe_warn(warnings, false, _message), do: warnings

  defp handle_chat_response(%{body: body}) do
    message = Map.get(body, "message", %{})

    with {:ok, content} <- parse_content(Map.get(message, "content")),
         {:ok, tool_calls_results} <- execute_tool_calls(Map.get(message, "tool_calls")) do
      payload = %{
        content: content,
        model: Map.get(body, "model"),
        finish_reason:
          Map.get(body, "done_reason") || if(Map.get(body, "done"), do: "stop", else: "unknown"),
        tool_calls: Map.get(message, "tool_calls"),
        tool_calls_results: tool_calls_results
      }

      metadata = %{
        created_at: Map.get(body, "created_at"),
        done: Map.get(body, "done"),
        performance: performance_summary(body)
      }

      %{
        schema_id: ResponseSignal,
        payload: payload,
        metadata: metadata
      }
      |> Lux.Signal.new()
      |> ResponseSignal.validate()
    end
  end

  defp parse_content(nil), do: {:ok, nil}

  defp parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, decoded} -> {:ok, %{"value" => decoded}}
      {:error, _} -> {:ok, %{"text" => content}}
    end
  end

  defp execute_tool_calls(nil), do: {:ok, nil}
  defp execute_tool_calls([]), do: {:ok, []}

  defp execute_tool_calls(tool_calls) when is_list(tool_calls) do
    tool_calls
    |> Enum.map(&execute_tool_call/1)
    |> Enum.reduce({:ok, []}, fn
      {:ok, result}, {:ok, results} -> {:ok, [result | results]}
      error, _ -> error
    end)
  end

  defp execute_tool_call(%{"function" => %{"name" => name, "arguments" => args}}) do
    args = if(is_map(args), do: args, else: Jason.decode!(args))
    execute_tool(name, args)
  end

  defp execute_tool_call(_tool_call), do: {:ok, %{}}

  defp execute_tool(name, args) when is_binary(name) do
    name
    |> String.replace("_", ".")
    |> List.wrap()
    |> Module.concat()
    |> Code.ensure_loaded()
    |> case do
      {:module, module_name} -> execute_tool(module_name, args)
      {:error, :nofile} -> {:error, "Failed to load tool module #{name}"}
      {:error, error} -> {:error, "Failed to load tool module #{name}: #{inspect(error)}"}
    end
  end

  defp execute_tool(module_name, args) when is_atom(module_name) do
    cond do
      Lux.prism?(module_name) -> module_name.handler(args, nil)
      Lux.beam?(module_name) -> module_name.run(args, nil)
      true -> {:error, "Tool #{module_name} is not a valid Beam or Prism"}
    end
  end

  defp normalize_model(model) do
    %{
      name: fetch_value(model, "name"),
      modified_at: fetch_value(model, "modified_at"),
      size: fetch_value(model, "size"),
      digest: fetch_value(model, "digest"),
      details: fetch_value(model, "details")
    }
    |> drop_empty_values()
  end

  defp post_json(config, path, body), do: request(:post, config, path, json: body)
  defp delete_json(config, path, body), do: request(:delete, config, path, json: body)
  defp get(config, path), do: request(:get, config, path, [])

  defp request(method, config, path, opts) do
    [
      url: endpoint_url(config.endpoint, path),
      headers: [{"Content-Type", "application/json"}],
      receive_timeout: config.receive_timeout
    ]
    |> Keyword.merge(opts)
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> then(&apply(Req, method, [&1]))
  end

  defp endpoint_url(endpoint, path), do: normalize_endpoint(endpoint) <> path

  defp normalize_endpoint(endpoint),
    do: endpoint |> Lux.Config.resolve() |> String.trim_trailing("/")

  defp maybe_put(map, _key, value) when value in [nil, [], %{}], do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp drop_empty_values(map),
    do: Map.reject(map, fn {_key, value} -> value in [nil, [], %{}] end)

  defp fetch_value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  defp duration_ms(nil), do: nil
  defp duration_ms(value) when is_integer(value), do: Float.round(value / 1_000_000, 2)
  defp duration_ms(value) when is_float(value), do: Float.round(value / 1_000_000, 2)
  defp duration_ms(_value), do: nil

  defp tokens_per_second(eval_count, eval_duration)
       when is_integer(eval_count) and is_integer(eval_duration) and eval_duration > 0 do
    Float.round(eval_count / (eval_duration / 1_000_000_000), 2)
  end

  defp tokens_per_second(_eval_count, _eval_duration), do: nil

  defp handle_error(error) do
    Logger.error("Error calling Ollama API: #{inspect(error)}")
    {:error, "Failed to call Ollama API"}
  end
end
