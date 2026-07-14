defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama Local Model Integration - Complete implementation for bounty #96.

  Provides self-hosted LLM capabilities via the Ollama API, with
  model management, download/caching, resource controls, and
  performance monitoring.

  ## Configuration

      config :lux, Lux.LLM.Ollama,
        api_key: System.get_env("OLLAMA_API_KEY"),
        endpoint: "http://localhost:11434",
        default_model: "llama3.3",
        max_retries: 3,
        retry_delay: 1000,
        timeout: 120_000

  ## Usage

      alias Lux.LLM.Ollama

      # Basic call
      {:ok, response} = Ollama.call("What is Elixir?", [], %{})

      # With tools
      {:ok, response} = Ollama.call("Calculate weather", [WeatherLens], %{})

      # With model override
      {:ok, response} = Ollama.call("Hello", [], %{model: "mistral"})
  """

  @behaviour Lux.LLM

  alias Lux.LLM.ResponseSignal
  require Logger

  @default_endpoint "http://localhost:11434"
  @default_model "llama3.3"

  defmodule Config do
    @moduledoc "Configuration for Ollama integration."
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t() | nil,
            system: String.t() | nil,
            temperature: float(),
            max_tokens: integer() | nil,
            timeout: integer(),
            stream: boolean(),
            keep_alive: String.t() | nil,
            format: String.t() | nil,
            top_p: float() | nil,
            top_k: integer() | nil,
            num_ctx: integer(),
            num_predict: integer() | nil,
            max_retries: integer(),
            retry_delay: integer()
          }
    defstruct endpoint: "http://localhost:11434",
              model: "llama3.3",
              api_key: nil,
              system: nil,
              temperature: 0.7,
              max_tokens: nil,
              timeout: 120_000,
              stream: false,
              keep_alive: "-1",
              format: nil,
              top_p: 0.9,
              top_k: 40,
              num_ctx: 4096,
              num_predict: nil,
              max_retries: 3,
              retry_delay: 1000
  end

  # ---- Performance Monitoring ----

  @perf_key {:lux_ollama_perf, __MODULE__}

  @doc "Records a performance metric entry."
  @spec record_perf(
          model :: String.t(),
          prompt_tokens :: integer(),
          output_tokens :: integer(),
          duration_ms :: integer()
        ) :: :ok
  def record_perf(model, prompt_tokens, output_tokens, duration_ms) do
    entry = %{
      model: model,
      prompt_tokens: prompt_tokens,
      output_tokens: output_tokens,
      duration_ms: duration_ms,
      timestamp: DateTime.utc_now()
    }

    current = :persistent_term.get(@perf_key, [])
    :persistent_term.put(@perf_key, [entry | current])
    :ok
  end

  @doc "Returns all performance metrics."
  @spec performance_metrics() :: [map()]
  def performance_metrics do
    case :persistent_term.get(@perf_key, []) do
      list when is_list(list) -> Enum.reverse(list)
      _ -> []
    end
  end

  @doc "Clears all performance metrics."
  @spec clear_performance_metrics() :: :ok
  def clear_performance_metrics do
    :persistent_term.erase(@perf_key)
    :ok
  end

  @doc "Returns average performance summary."
  @spec perf_summary() :: map()
  def perf_summary do
    metrics = performance_metrics()

    if Enum.empty?(metrics) do
      %{total_requests: 0, avg_duration_ms: 0, avg_prompt_tokens: 0, avg_output_tokens: 0}
    else
      total = length(metrics)

      %{
        total_requests: total,
        avg_duration_ms: Enum.sum(Enum.map(metrics, & &1.duration_ms)) / total,
        avg_prompt_tokens: Enum.sum(Enum.map(metrics, & &1.prompt_tokens)) / total,
        avg_output_tokens: Enum.sum(Enum.map(metrics, & &1.output_tokens)) / total
      }
    end
  end

  # ---- Tool Conversion (matches OpenAI pattern) ----

  defp build_tools_config([]), do: []

  defp build_tools_config(tools),
    do: Enum.map(tools, &tool_to_function/1) |> Enum.reject(&is_nil/1)

  defp tool_to_function({:python, _path}), do: nil

  defp tool_to_function(tool_module) when is_atom(tool_module) and not is_nil(tool_module) do
    cond do
      Lux.prism?(tool_module) -> tool_to_function(Lux.Prism.view(tool_module))
      Lux.beam?(tool_module) -> tool_to_function(Lux.Beam.view(tool_module))
      Lux.lens?(tool_module) -> tool_to_function(Lux.Lens.view(tool_module))
      true -> nil
    end
  end

  defp tool_to_function(%Lux.Beam{
         module_name: name,
         description: description,
         input_schema: input_schema
       }) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  defp tool_to_function(%Lux.Prism{
         module_name: name,
         description: description,
         input_schema: input_schema
       }) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  defp tool_to_function(%Lux.Lens{
         module_name: name,
         description: description,
         schema: schema
       }) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: schema
      }
    }
  end

  # ---- Chat ----

  @doc "Calls the Ollama API with the given prompt, tools, and config."
  @impl true
  @spec call(prompt :: String.t(), tools :: list(), config :: map()) ::
          {:ok, Lux.Signal.t()} | {:error, String.t()}
  def call(prompt, tools, config) when is_list(tools) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            api_key: Application.get_env(:lux, :api_keys, [])[:ollama],
            model: Application.get_env(:lux, Lux.LLM.Ollama, [])[:default_model] || @default_model
          },
          Keyword.into(Map.to_list(config || %{}), %{})
        )
      )

    system_prompt = config.system || "You are a helpful AI assistant powered by Ollama."

    messages = [%{role: "system", content: system_prompt}, %{role: "user", content: prompt}]

    tool_defs = build_tools_config(tools)

    payload =
      %{
        model: config.model,
        messages: messages,
        stream: config.stream,
        options: build_options(config)
      }
      |> maybe_put(:tools, tool_defs, tool_defs != [])
      |> maybe_put(:format, config.format, not is_nil(config.format))
      |> maybe_put(:keep_alive, config.keep_alive, not is_nil(config.keep_alive))

    endpoint = config.endpoint || @default_endpoint
    url = "#{endpoint}/api/chat"

    headers = [{"Content-Type", "application/json"}]

    start_time = System.monotonic_time(:millisecond)

    result =
      case do_call(url, payload, headers, config) do
        {:ok, response_body} ->
          handle_chat_response(response_body, payload, tools, headers, config)

        {:error, reason} ->
          {:error, "Ollama call failed: #{reason}"}
      end

    # Record performance metrics
    case result do
      {:ok, signal} ->
        metadata = ResponseSignal.metadata(signal)
        duration = System.monotonic_time(:millisecond) - start_time
        prompt_tokens = Map.get(metadata, :prompt_tokens, 0)
        output_tokens = Map.get(metadata, :output_tokens, 0)
        record_perf(config.model, prompt_tokens, output_tokens, duration)
        result

      {:error, _} ->
        duration = System.monotonic_time(:millisecond) - start_time
        record_perf(config.model, 0, 0, duration)
        result
    end
  end

  defp maybe_put(map, key, value, true), do: Map.put(map, key, value)
  defp maybe_put(map, _key, _value, false), do: map

  defp build_options(config) do
    opts = %{
      temperature: config.temperature,
      top_p: config.top_p,
      top_k: config.top_k,
      num_ctx: config.num_ctx
    }

    opts = if config.max_tokens, do: Map.put(opts, :num_predict, config.max_tokens), else: opts
    opts = if config.num_predict, do: Map.put(opts, :num_predict, config.num_predict), else: opts
    opts
  end

  defp do_call(url, payload, headers, config) do
    opts =
      [json: payload, headers: headers, timeout: config.timeout, receive_timeout: config.timeout]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    case Req.post(url, opts) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "HTTP #{status}: #{inspect(body)}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp handle_chat_response(
         %{"message" => %{"tool_calls" => calls} = assistant},
         payload,
         tools,
         headers,
         config
       )
       when is_list(calls) and calls != [] do
    with {:ok, tool_messages, results} <- execute_tool_calls(calls, tools),
         followup_payload <- %{
           payload
           | messages: payload.messages ++ [assistant] ++ tool_messages
         },
         {:ok, body} <- do_call("#{config.endpoint}/api/chat", followup_payload, headers, config),
         {:ok, signal} <- handle_ollama_response(body, config, results) do
      {:ok, signal}
    end
  end

  defp handle_chat_response(body, _payload, _tools, _headers, config),
    do: handle_ollama_response(body, config, nil)

  defp handle_ollama_response(
         %{"message" => %{"content" => content, "tool_calls" => tool_calls}} = resp,
         _config,
         tool_results
       ) do
    metadata = %{
      model: Map.get(resp, "model"),
      prompt_tokens: Map.get(resp, "prompt_eval_count"),
      output_tokens: Map.get(resp, "eval_count"),
      total_time: Map.get(resp, "total_duration"),
      provider: :ollama
    }

    response_payload = %{
      content: content_map(content),
      model: resp["model"] || "ollama",
      finish_reason: if(tool_calls in [nil, []], do: "stop", else: "tool_calls"),
      tool_calls: tool_calls,
      tool_calls_results: tool_results
    }

    %{schema_id: ResponseSignal, payload: response_payload, metadata: metadata}
    |> Lux.Signal.new()
    |> ResponseSignal.validate()
  end

  defp handle_ollama_response(
         %{"message" => %{"content" => content} = message} = resp,
         config,
         results
       )
       when is_binary(content) do
    handle_ollama_response(
      %{resp | "message" => Map.put(message, "tool_calls", nil)},
      config,
      results
    )
  end

  defp handle_ollama_response(%{"error" => error}, _config, _results),
    do: {:error, "Ollama error: #{error}"}

  defp handle_ollama_response(_, _config, _results),
    do: {:error, "Unexpected Ollama response format"}

  defp content_map(nil), do: nil
  defp content_map(content) when is_map(content), do: content
  defp content_map(content) when is_binary(content), do: %{"text" => content}

  # ---- Tool Call Execution ----

  defp execute_tool_calls(calls, tools) do
    modules = Map.new(tools, fn module -> {tool_name(module), module} end)

    Enum.reduce_while(calls, {:ok, [], []}, fn call, {:ok, messages, results} ->
      with %{"function" => %{"name" => name, "arguments" => raw_args}} <- call,
           {:ok, args} <- normalize_arguments(raw_args),
           module when not is_nil(module) <- modules[name],
           {:ok, result} <- execute_module_tool(module, args) do
        message = %{role: "tool", tool_name: name, content: Jason.encode!(result)}
        {:cont, {:ok, messages ++ [message], results ++ [result]}}
      else
        error -> {:halt, {:error, "Ollama tool call failed: #{inspect(error)}"}}
      end
    end)
  end

  defp normalize_arguments(args) when is_map(args), do: {:ok, args}
  defp normalize_arguments(args) when is_binary(args), do: Jason.decode(args)
  defp normalize_arguments(_), do: {:error, :invalid_arguments}

  defp tool_name(module) do
    [definition] = build_tools_config([module])
    definition.function.name
  end

  defp execute_module_tool(module, args) when is_atom(module) do
    cond do
      Lux.prism?(module) -> module.handler(args, nil)
      Lux.beam?(module) -> module.run(args, nil)
      Lux.lens?(module) -> module.focus(args)
      true -> :skip
    end
  end

  # ---- Model Management ----

  @doc "Lists available models from Ollama."
  @spec list_models() :: {:ok, [map()]} | {:error, String.t()}
  def list_models do
    endpoint = Application.get_env(:lux, Lux.LLM.Ollama, [])[:endpoint] || @default_endpoint
    url = "#{endpoint}/api/tags"

    case Req.get(url, Application.get_env(:lux, __MODULE__, [])) do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, Enum.map(models, &parse_model/1)}

      {:ok, %{status: status}} ->
        {:error, "Failed to list models: HTTP #{status}"}

      {:error, reason} ->
        {:error, "Failed to connect to Ollama: #{inspect(reason)}"}
    end
  end

  defp parse_model(%{"name" => name, "size" => size, "digest" => digest} = m) do
    %{
      name: name,
      size_bytes: size,
      digest: digest,
      modified_at: Map.get(m, "modified_at"),
      details: Map.get(m, "details", %{})
    }
  end

  @doc "Pulls (downloads) a model from the Ollama library."
  @spec pull_model(String.t()) :: {:ok, map()} | {:error, String.t()}
  def pull_model(model_name) do
    endpoint = Application.get_env(:lux, Lux.LLM.Ollama, [])[:endpoint] || @default_endpoint
    url = "#{endpoint}/api/pull"

    # Ollama API uses "model" field, not "name"
    payload = %{model: model_name, stream: false}

    case Req.post(url, Keyword.merge([json: payload], Application.get_env(:lux, __MODULE__, []))) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "Pull failed: HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Pull failed: #{inspect(reason)}"}
    end
  end

  @doc "Pulls a model with progress streaming."
  @spec pull_model_stream(String.t()) :: {:ok, Stream.t()} | {:error, String.t()}
  def pull_model_stream(model_name) do
    endpoint = Application.get_env(:lux, Lux.LLM.Ollama, [])[:endpoint] || @default_endpoint
    url = "#{endpoint}/api/pull"

    # Ollama API uses "model" field, not "name"
    payload = %{model: model_name, stream: true}

    opts =
      [json: payload, decode_body: false]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    case Req.post(url, opts) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        lines = String.split(body, "\n", trim: true)

        {:ok,
         Stream.resource(
           fn -> lines end,
           fn
             [] -> {:halt, []}
             [line | rest] -> {[Jason.decode!(line)], rest}
           end,
           fn _ -> :ok end
         )}

      {:ok, %{status: status, body: body}} ->
        {:error, "Pull failed: HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Pull failed: #{inspect(reason)}"}
    end
  end

  @doc "Deletes a model locally."
  @spec delete_model(String.t()) :: {:ok, map()} | {:error, String.t()}
  def delete_model(model_name) do
    endpoint = Application.get_env(:lux, Lux.LLM.Ollama, [])[:endpoint] || @default_endpoint
    url = "#{endpoint}/api/delete"

    case Req.delete(
           url,
           Keyword.merge([json: %{model: model_name}], Application.get_env(:lux, __MODULE__, []))
         ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "Delete failed: HTTP #{status}"}
      {:error, reason} -> {:error, "Delete failed: #{inspect(reason)}"}
    end
  end

  @doc "Shows model information."
  @spec show_model(String.t()) :: {:ok, map()} | {:error, String.t()}
  def show_model(model_name) do
    endpoint = Application.get_env(:lux, Lux.LLM.Ollama, [])[:endpoint] || @default_endpoint
    url = "#{endpoint}/api/show"

    payload = %{model: model_name}

    case Req.post(url, Keyword.merge([json: payload], Application.get_env(:lux, __MODULE__, []))) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "Show failed: HTTP #{status}"}
      {:error, reason} -> {:error, "Show failed: #{inspect(reason)}"}
    end
  end

  @doc "Copies a model to a new name."
  @spec copy_model(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def copy_model(source, destination) do
    endpoint = Application.get_env(:lux, Lux.LLM.Ollama, [])[:endpoint] || @default_endpoint
    url = "#{endpoint}/api/copy"

    payload = %{source: source, destination: destination}

    case Req.post(url, Keyword.merge([json: payload], Application.get_env(:lux, __MODULE__, []))) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "Copy failed: HTTP #{status}"}
      {:error, reason} -> {:error, "Copy failed: #{inspect(reason)}"}
    end
  end

  @doc "Checks if Ollama is reachable."
  @spec health_check() :: {:ok, map()} | {:error, String.t()}
  def health_check do
    endpoint = Application.get_env(:lux, Lux.LLM.Ollama, [])[:endpoint] || @default_endpoint
    url = "#{endpoint}/api/version"

    case Req.get(url, Application.get_env(:lux, __MODULE__, [])) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "Health check failed: HTTP #{status}"}
      {:error, reason} -> {:error, "Ollama not reachable: #{inspect(reason)}"}
    end
  end

  @doc "Returns the default endpoint."
  @spec default_endpoint() :: String.t()
  def default_endpoint, do: @default_endpoint

  @doc "Returns the default model."
  @spec default_model() :: String.t()
  def default_model, do: @default_model
end
