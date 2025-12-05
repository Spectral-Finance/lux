defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation for local model support.

  This module provides integration with Ollama for self-hosted LLM capabilities,
  supporting:
  - Local model inference via Ollama API
  - Model management (list, pull, delete)
  - Tool calling with Beams, Prisms, and Lenses
  - Resource monitoring and performance tracking

  ## Configuration

  Configure Ollama in your config files:

      config :lux, Lux.LLM.Ollama,
        endpoint: "http://localhost:11434",
        receive_timeout: 120_000

      config :lux, :ollama_models,
        default: "llama3.2",
        smartest: "llama3.2:70b",
        fastest: "llama3.2:1b"

  ## Usage

      # Basic usage
      Lux.LLM.Ollama.call("What is the capital of France?", [], %{})

      # With specific model
      Lux.LLM.Ollama.call("Explain quantum computing", [], %{model: "llama3.2:70b"})

      # List available models
      Lux.LLM.Ollama.list_models()

      # Pull a new model
      Lux.LLM.Ollama.pull_model("mistral")

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
  @chat_path "/api/chat"
  @generate_path "/api/generate"
  @tags_path "/api/tags"
  @pull_path "/api/pull"
  @delete_path "/api/delete"
  @show_path "/api/show"

  defmodule Config do
    @moduledoc """
    Configuration module for Ollama.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            temperature: float(),
            num_predict: integer() | nil,
            top_k: integer() | nil,
            top_p: float() | nil,
            repeat_penalty: float() | nil,
            seed: integer() | nil,
            num_ctx: integer() | nil,
            num_gpu: integer() | nil,
            receive_timeout: integer(),
            json_response: boolean(),
            stream: boolean(),
            keep_alive: String.t() | integer() | nil,
            messages: [map()]
          }

    defstruct endpoint: "http://localhost:11434",
              model: "llama3.2",
              temperature: 0.7,
              num_predict: nil,
              top_k: nil,
              top_p: nil,
              repeat_penalty: nil,
              seed: nil,
              num_ctx: nil,
              num_gpu: nil,
              receive_timeout: 120_000,
              json_response: true,
              stream: false,
              keep_alive: nil,
              messages: []
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: get_default_model(),
            endpoint: get_endpoint()
          },
          config
        )
      )

    messages = config.messages ++ build_messages(prompt, config)
    tools_config = build_tools_config(tools)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        stream: config.stream,
        options: build_options(config)
      }
      |> maybe_add_tools(tools_config)
      |> maybe_add_format(config)

    url = "#{config.endpoint}#{@chat_path}"

    [
      url: url,
      json: body,
      headers: [
        {"Content-Type", "application/json"}
      ],
      receive_timeout: config.receive_timeout
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: status, body: body}} when is_map(body) ->
        {:error, {status, body["error"] || "Unknown error"}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, :ollama_not_running}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  List all locally available models.

  ## Example

      {:ok, models} = Lux.LLM.Ollama.list_models()
      # Returns list of model info maps

  """
  @spec list_models(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_models(opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, get_endpoint())
    url = "#{endpoint}#{@tags_path}"

    case Req.get(url) do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, models}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, :ollama_not_running}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Pull (download) a model from the Ollama library.

  ## Options

  - `:endpoint` - Ollama server endpoint (default: configured endpoint)
  - `:insecure` - Allow insecure connections (default: false)
  - `:stream` - Stream progress updates (default: false)

  ## Example

      {:ok, result} = Lux.LLM.Ollama.pull_model("llama3.2")
      {:ok, result} = Lux.LLM.Ollama.pull_model("mistral:7b")

  """
  @spec pull_model(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def pull_model(model_name, opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, get_endpoint())
    url = "#{endpoint}#{@pull_path}"

    body = %{
      name: model_name,
      insecure: Keyword.get(opts, :insecure, false),
      stream: Keyword.get(opts, :stream, false)
    }

    Logger.info("Pulling Ollama model: #{model_name}")

    case Req.post(url, json: body, receive_timeout: 600_000) do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("Successfully pulled model: #{model_name}")
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, :ollama_not_running}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Delete a model from Ollama.

  ## Example

      {:ok, _} = Lux.LLM.Ollama.delete_model("llama3.2:latest")

  """
  @spec delete_model(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete_model(model_name, opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, get_endpoint())
    url = "#{endpoint}#{@delete_path}"

    case Req.request(method: :delete, url: url, json: %{name: model_name}) do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("Deleted model: #{model_name}")
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Show information about a model.

  ## Example

      {:ok, info} = Lux.LLM.Ollama.show_model("llama3.2")

  """
  @spec show_model(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def show_model(model_name, opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, get_endpoint())
    url = "#{endpoint}#{@show_path}"

    case Req.post(url, json: %{name: model_name}) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Check if Ollama server is running and accessible.

  ## Example

      :ok = Lux.LLM.Ollama.health_check()
      {:error, :ollama_not_running} = Lux.LLM.Ollama.health_check()

  """
  @spec health_check(keyword()) :: :ok | {:error, term()}
  def health_check(opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, get_endpoint())

    case Req.get(endpoint) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status}} -> {:error, {:unexpected_status, status}}
      {:error, %Req.TransportError{reason: :econnrefused}} -> {:error, :ollama_not_running}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Ensure a model is available locally, pulling it if necessary.

  ## Example

      {:ok, model_info} = Lux.LLM.Ollama.ensure_model("llama3.2")

  """
  @spec ensure_model(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def ensure_model(model_name, opts \\ []) do
    case show_model(model_name, opts) do
      {:ok, info} ->
        {:ok, info}

      {:error, {404, _}} ->
        Logger.info("Model #{model_name} not found locally, pulling...")
        pull_model(model_name, opts)

      {:error, error} ->
        {:error, error}
    end
  end

  # Private functions

  defp get_endpoint do
    Application.get_env(:lux, __MODULE__, [])
    |> Keyword.get(:endpoint, @default_endpoint)
  end

  defp get_default_model do
    case Application.get_env(:lux, :ollama_models) do
      nil -> "llama3.2"
      models -> models[:default] || "llama3.2"
    end
  end

  defp build_messages(prompt, config) do
    content =
      if config.json_response do
        prompt <> "\n\nRespond with valid JSON only."
      else
        prompt
      end

    [%{role: "user", content: content}]
  end

  defp build_options(config) do
    %{}
    |> maybe_put(:temperature, config.temperature)
    |> maybe_put(:num_predict, config.num_predict)
    |> maybe_put(:top_k, config.top_k)
    |> maybe_put(:top_p, config.top_p)
    |> maybe_put(:repeat_penalty, config.repeat_penalty)
    |> maybe_put(:seed, config.seed)
    |> maybe_put(:num_ctx, config.num_ctx)
    |> maybe_put(:num_gpu, config.num_gpu)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body

  defp maybe_add_tools(body, tools) do
    Map.put(body, :tools, tools)
  end

  defp maybe_add_format(body, %Config{json_response: true}) do
    Map.put(body, :format, "json")
  end

  defp maybe_add_format(body, _config), do: body

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

  defp handle_response(%{body: body}, _config) do
    with %{"message" => message} <- body,
         content <- message["content"],
         {:ok, parsed_content} <- parse_content(content),
         {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
      payload = %{
        content: parsed_content,
        model: body["model"],
        finish_reason: if(body["done"], do: "stop", else: nil),
        tool_calls: message["tool_calls"],
        tool_calls_results: tool_calls_results
      }

      metadata = %{
        created_at: body["created_at"],
        done: body["done"],
        total_duration: body["total_duration"],
        load_duration: body["load_duration"],
        prompt_eval_count: body["prompt_eval_count"],
        prompt_eval_duration: body["prompt_eval_duration"],
        eval_count: body["eval_count"],
        eval_duration: body["eval_duration"]
      }

      %{
        schema_id: ResponseSignal,
        payload: payload,
        metadata: metadata
      }
      |> Lux.Signal.new()
      |> ResponseSignal.validate()
    else
      error ->
        Logger.error("Failed to parse Ollama response: #{inspect(error)}")
        {:error, "Failed to parse response: #{inspect(error)}"}
    end
  end

  defp parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} ->
        {:ok, structured_output}

      {:error, _} ->
        # Return raw content if not valid JSON
        {:ok, content}
    end
  end

  defp parse_content(nil), do: {:ok, nil}

  defp execute_tool_calls(tool_calls) when is_list(tool_calls) do
    tool_calls
    |> Enum.map(&execute_tool_call/1)
    |> Enum.reduce({:ok, []}, fn
      {:ok, result, _log}, {:ok, results} ->
        {:ok, [result | results]}

      {:ok, result}, {:ok, results} ->
        {:ok, [result | results]}

      error, _ ->
        error
    end)
  end

  defp execute_tool_calls(nil), do: {:ok, nil}

  defp execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
    args =
      case args do
        args when is_binary(args) -> Jason.decode!(args)
        args when is_map(args) -> args
      end

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
         "Failed to load tool module #{tool_name}: It doesn't seem to be implemented or reachable"}

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
         Tool #{tool_module} does not seem to be a valid Beam or Prism
         as it does not have a registered `handler` or `run` function.
         """}
    end
  end

  defp handle_error(%Req.TransportError{reason: :timeout}) do
    Logger.error("Ollama request timeout")
    {:error, :timeout}
  end

  defp handle_error(%Req.TransportError{reason: :econnrefused}) do
    Logger.error("Ollama server not running at configured endpoint")
    {:error, :ollama_not_running}
  end

  defp handle_error(error) do
    Logger.error("Ollama API error: #{inspect(error)}")
    {:error, "Ollama API error: #{inspect(error)}"}
  end
end
