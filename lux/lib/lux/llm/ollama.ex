defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation for local, self-hosted model inference.

  This module uses Ollama's local HTTP API and supports Lux tools, model
  management helpers, JSON responses, resource controls, and response metadata
  with Ollama timing counters.
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @message_roles ["system", "user", "assistant", "tool"]

  defmodule Config do
    @moduledoc """
    Configuration for local Ollama calls.
    """

    @type t :: %__MODULE__{
            base_url: String.t(),
            endpoint: String.t() | nil,
            model: String.t(),
            temperature: float() | nil,
            top_p: float() | nil,
            top_k: integer() | nil,
            max_tokens: integer() | nil,
            seed: integer() | nil,
            num_ctx: integer() | nil,
            num_gpu: integer() | nil,
            num_thread: integer() | nil,
            keep_alive: String.t() | integer() | nil,
            receive_timeout: integer(),
            stream: boolean(),
            json_response: boolean(),
            json_schema: map() | nil,
            messages: [map()],
            auto_pull: boolean()
          }

    defstruct base_url: "http://localhost:11434",
              endpoint: nil,
              model: "llama3.2",
              temperature: 0.7,
              top_p: 0.9,
              top_k: nil,
              max_tokens: nil,
              seed: nil,
              num_ctx: nil,
              num_gpu: nil,
              num_thread: nil,
              keep_alive: "5m",
              receive_timeout: 60_000,
              stream: false,
              json_response: true,
              json_schema: nil,
              messages: [],
              auto_pull: false
  end

  @impl true
  def call(prompt, tools, config) do
    config = build_config(config)

    with :ok <- maybe_ensure_model(config) do
      messages = config.messages ++ build_messages(prompt)
      tools_config = build_tools_config(tools)

      body =
        %{
          model: Lux.Config.resolve(config.model),
          messages: messages,
          stream: config.stream,
          keep_alive: config.keep_alive
        }
        |> maybe_add_options(config)
        |> maybe_add_tools(tools_config)
        |> maybe_add_response_format(config)

      [
        url: endpoint(config, "/api/chat"),
        json: body,
        receive_timeout: config.receive_timeout
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> Req.new()
      |> Req.post()
      |> case do
        {:ok, %{status: 200} = response} ->
          handle_response(response, config)

        {:ok, %{status: status, body: %{"error" => message}}} ->
          {:error, {status, message}}

        {:ok, %{status: status, body: body}} ->
          {:error, {status, body}}

        {:error, error} ->
          handle_error(error)
      end
    end
  end

  @doc """
  Returns models available in the local Ollama cache.
  """
  def list_models(config \\ %{}) do
    config = build_config(config)

    [
      url: endpoint(config, "/api/tags"),
      receive_timeout: config.receive_timeout
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, models}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Checks whether a model is already available locally.
  """
  def model_available?(model, config \\ %{}) do
    with {:ok, models} <- list_models(config) do
      resolved_model = Lux.Config.resolve(model)

      available? =
        Enum.any?(models, fn model_info ->
          model_info["name"] == resolved_model || model_info["model"] == resolved_model
        end)

      {:ok, available?}
    end
  end

  @doc """
  Pulls a model into Ollama's local model cache.
  """
  def pull_model(model, config \\ %{}) do
    config = build_config(config)

    [
      url: endpoint(config, "/api/pull"),
      json: %{model: Lux.Config.resolve(model), stream: false},
      receive_timeout: config.receive_timeout
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Returns local model details from Ollama.
  """
  def show_model(model, config \\ %{}) do
    config = build_config(config)

    [
      url: endpoint(config, "/api/show"),
      json: %{model: Lux.Config.resolve(model)},
      receive_timeout: config.receive_timeout
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Ensures the model exists locally, pulling it only when missing.
  """
  def ensure_model(model, config \\ %{}) do
    case model_available?(model, config) do
      {:ok, true} -> {:ok, :cached}
      {:ok, false} -> pull_model(model, config)
      error -> error
    end
  end

  @doc """
  Loads a model into memory using Ollama's keep_alive behavior.
  """
  def load_model(model, config \\ %{}) do
    config = build_config(config)

    [
      url: endpoint(config, "/api/chat"),
      json: %{model: Lux.Config.resolve(model), messages: [], keep_alive: config.keep_alive},
      receive_timeout: config.receive_timeout
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Unloads a model from memory.
  """
  def unload_model(model, config \\ %{}) do
    load_model(model, Map.merge(normalize_config(config), %{keep_alive: 0}))
  end

  def tool_to_function({:python, path}) do
    path
    |> Prism.view()
    |> tool_to_function()
  end

  def tool_to_function(tool_module) when is_atom(tool_module) and not is_nil(tool_module) do
    cond do
      Lux.prism?(tool_module) ->
        tool_to_function(tool_module.view())

      Lux.beam?(tool_module) ->
        tool_to_function(tool_module.view())

      Lux.lens?(tool_module) ->
        tool_to_function(tool_module.view())

      true ->
        raise "Unsupported tool type: #{inspect(tool_module)}"
    end
  end

  def tool_to_function(%Beam{
        module_name: name,
        name: fallback,
        description: description,
        input_schema: input_schema
      }) do
    function_name = tool_name(name || fallback)

    %{
      type: "function",
      function: %{
        name: function_name,
        description: description || "",
        parameters: input_schema || %{}
      }
    }
  end

  def tool_to_function(%Prism{
        module_name: name,
        name: fallback,
        description: description,
        input_schema: input_schema
      }) do
    function_name = tool_name(name || fallback)

    %{
      type: "function",
      function: %{
        name: function_name,
        description: description || "",
        parameters: input_schema || %{}
      }
    }
  end

  def tool_to_function(%Lens{
        module_name: name,
        name: fallback,
        description: description,
        schema: schema
      }) do
    function_name = tool_name(name || fallback || "unnamed_lens")

    %{
      type: "function",
      function: %{
        name: function_name,
        description: description || "",
        parameters: schema || %{}
      }
    }
  end

  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} -> {:ok, structured_output}
      {:error, _} -> {:ok, %{"text" => content}}
    end
  end

  def parse_content(_), do: {:ok, nil}

  def execute_tool_calls(tool_calls) when is_list(tool_calls) do
    tool_calls
    |> Enum.map(&execute_tool_call/1)
    |> Enum.reduce({:ok, []}, fn
      {:ok, result, _log}, {:ok, results} -> {:ok, [result | results]}
      {:ok, result}, {:ok, results} -> {:ok, [result | results]}
      error, _ -> error
    end)
  end

  def execute_tool_calls(nil), do: {:ok, nil}

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}})
      when is_binary(args) do
    args = Jason.decode!(args)
    execute_tool(tool_name, args, nil)
  end

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}})
      when is_map(args) do
    execute_tool(tool_name, args, nil)
  end

  def execute_tool(tool_name, args, ctx \\ nil)

  def execute_tool(tool_name, args, ctx) when is_binary(tool_name) do
    tool_name
    |> String.replace("_", ".")
    |> List.wrap()
    |> Module.concat()
    |> Code.ensure_loaded()
    |> case do
      {:module, module_name} ->
        execute_tool(module_name, args, ctx)

      {:error, :nofile} ->
        {:error,
         """
         Failed to load tool module #{tool_name}: It doesn't seem to be implemented or reachable
         """}

      {:error, error} ->
        {:error, "Failed to load tool module #{tool_name}: #{inspect(error)}"}
    end
  end

  def execute_tool(tool_module, args, ctx) when is_atom(tool_module) do
    cond do
      Lux.prism?(tool_module) ->
        tool_module.handler(args, ctx)

      Lux.beam?(tool_module) ->
        tool_module.run(args, ctx)

      Lux.lens?(tool_module) ->
        tool_module.focus(args)

      true ->
        {:error,
         """
         Tool #{tool_module} does not seem to be a valid Beam, Lens, or Prism.
         """}
    end
  end

  defp build_config(config) do
    defaults = %{
      model: Application.get_env(:lux, :ollama_models, [])[:default] || "llama3.2"
    }

    struct(Config, Map.merge(defaults, normalize_config(config)))
  end

  defp normalize_config(nil), do: %{}
  defp normalize_config(%Config{} = config), do: Map.from_struct(config)
  defp normalize_config(config) when is_map(config), do: config
  defp normalize_config(config) when is_list(config), do: Map.new(config)

  defp maybe_ensure_model(%Config{auto_pull: false}), do: :ok

  defp maybe_ensure_model(%Config{auto_pull: true, model: model} = config) do
    case ensure_model(model, config) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp build_messages(prompt) when is_binary(prompt), do: [%{role: "user", content: prompt}]

  defp build_messages(messages) when is_list(messages) do
    Enum.map(messages, fn
      %{role: role, content: _content} = message when role in @message_roles ->
        message

      message when is_binary(message) ->
        %{role: "user", content: message}
    end)
  end

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  defp maybe_add_options(body, config) do
    options =
      %{
        temperature: config.temperature,
        top_p: config.top_p,
        top_k: config.top_k,
        num_predict: config.max_tokens,
        seed: config.seed,
        num_ctx: config.num_ctx,
        num_gpu: config.num_gpu,
        num_thread: config.num_thread
      }
      |> reject_nil_values()

    if map_size(options) == 0, do: body, else: Map.put(body, :options, options)
  end

  defp maybe_add_response_format(body, %Config{json_response: false}), do: body

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_map(schema) do
    Map.put(body, :format, schema)
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: nil}) do
    body
    |> Map.update!(:messages, &append_json_instruction/1)
    |> Map.put(:format, "json")
  end

  defp append_json_instruction(messages) do
    messages ++ [%{role: "system", content: "Reply in JSON format."}]
  end

  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp handle_response(%{body: body}, _config) do
    with %{"message" => message} <- body,
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
      payload = %{
        content: content,
        model: body["model"],
        finish_reason: body["done_reason"] || finish_reason(body),
        tool_calls: message["tool_calls"],
        tool_calls_results: tool_calls_results
      }

      metadata = %{
        created: body["created_at"],
        usage: usage(body),
        performance: performance(body),
        done: body["done"]
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

  defp finish_reason(%{"done" => true}), do: "stop"
  defp finish_reason(_), do: nil

  defp usage(body) do
    %{
      prompt_tokens: body["prompt_eval_count"],
      completion_tokens: body["eval_count"],
      total_tokens: total_tokens(body)
    }
    |> reject_nil_values()
  end

  defp total_tokens(body) do
    prompt_tokens = body["prompt_eval_count"] || 0
    completion_tokens = body["eval_count"] || 0

    if prompt_tokens == 0 and completion_tokens == 0 do
      nil
    else
      prompt_tokens + completion_tokens
    end
  end

  defp performance(body) do
    %{
      total_duration: body["total_duration"],
      load_duration: body["load_duration"],
      prompt_eval_duration: body["prompt_eval_duration"],
      eval_duration: body["eval_duration"],
      tokens_per_second: tokens_per_second(body)
    }
    |> reject_nil_values()
  end

  defp tokens_per_second(%{"eval_count" => count, "eval_duration" => duration})
       when is_number(count) and is_number(duration) and duration > 0 do
    count / (duration / 1_000_000_000)
  end

  defp tokens_per_second(_), do: nil

  defp endpoint(%Config{endpoint: endpoint}, _path) when is_binary(endpoint), do: endpoint

  defp endpoint(%Config{base_url: base_url}, path) do
    String.trim_trailing(base_url, "/") <> path
  end

  defp tool_name(name) do
    name
    |> to_string()
    |> String.replace(".", "_")
  end

  defp handle_error(error) do
    Logger.error("Ollama API error: #{inspect(error)}")
    {:error, "Ollama API error: #{inspect(error)}"}
  end
end
