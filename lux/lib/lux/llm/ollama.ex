defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation for local model support via Ollama.

  Enables self-hosted LLM capabilities with optimized performance, including:
  - Local model inference via Ollama API (`/api/chat`)
  - Model management (list, pull, delete, show, ensure)
  - Tool calling support with Beams, Prisms, and Lenses
  - Health checking and configuration via environment variables
  - Resource controls (num_ctx, num_gpu, keep_alive, etc.)
  - Performance monitoring via response metadata

  ## Configuration

  Configure via application env or pass options directly:

      config :lux, :ollama_models,
        default: "llama3.2:latest"

      config :lux, Lux.LLM.Ollama,
        base_url: "http://localhost:11434"

  Or via environment variables:
  - `OLLAMA_BASE_URL` - Base URL for Ollama server (default: http://localhost:11434)
  - `OLLAMA_MODEL` - Default model to use (default: llama3.2:latest)

  ## Usage

      # Basic call
      Lux.LLM.Ollama.call("Hello!", [], %{model: "llama3.2:latest"})

      # With tools
      Lux.LLM.Ollama.call("What's the weather?", [MyWeatherPrism], %{})

      # Model management
      Lux.LLM.Ollama.list_models()
      Lux.LLM.Ollama.pull_model("llama3.2:latest")
      Lux.LLM.Ollama.show_model("llama3.2:latest")
      Lux.LLM.Ollama.delete_model("llama3.2:latest")
      Lux.LLM.Ollama.ensure_model("llama3.2:latest")

      # Health check
      Lux.LLM.Ollama.health_check()
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
  @default_model "llama3.2:latest"

  defmodule Config do
    @moduledoc """
    Configuration module for Ollama.

    ## Fields

    - `:base_url` - Base URL for the Ollama server (default: http://localhost:11434)
    - `:model` - Model to use for inference (default: llama3.2:latest)
    - `:temperature` - Sampling temperature (default: 0.7)
    - `:num_ctx` - Context window size (default: nil, uses model default)
    - `:num_gpu` - Number of GPU layers to offload (default: nil)
    - `:num_predict` - Maximum number of tokens to generate (default: nil)
    - `:top_p` - Top-p sampling parameter (default: nil)
    - `:top_k` - Top-k sampling parameter (default: nil)
    - `:seed` - Random seed for reproducibility (default: nil)
    - `:keep_alive` - How long to keep the model loaded (default: nil, uses Ollama default)
    - `:receive_timeout` - HTTP receive timeout in ms (default: 120_000)
    - `:system` - System prompt (default: nil)
    - `:json_response` - Whether to request JSON output (default: true)
    - `:messages` - Conversation history (default: [])
    """
    @type t :: %__MODULE__{
            base_url: String.t(),
            model: String.t(),
            temperature: float(),
            num_ctx: integer() | nil,
            num_gpu: integer() | nil,
            num_predict: integer() | nil,
            top_p: float() | nil,
            top_k: integer() | nil,
            seed: integer() | nil,
            keep_alive: String.t() | integer() | nil,
            receive_timeout: integer(),
            system: String.t() | nil,
            json_response: boolean(),
            messages: [map()]
          }

    defstruct base_url: "http://localhost:11434",
              model: "llama3.2:latest",
              temperature: 0.7,
              num_ctx: nil,
              num_gpu: nil,
              num_predict: nil,
              top_p: nil,
              top_k: nil,
              seed: nil,
              keep_alive: nil,
              receive_timeout: 120_000,
              system: nil,
              json_response: true,
              messages: []
  end

  # ---------------------------------------------------------------------------
  # LLM Behaviour - call/3
  # ---------------------------------------------------------------------------

  @impl true
  def call(prompt, tools, config) do
    config = build_config(config)

    messages = config.messages ++ build_messages(prompt, config.system)
    tools_config = build_tools_config(tools)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        stream: false
      }
      |> add_options(config)
      |> maybe_add_tools(tools_config)
      |> maybe_add_format(config, tools_config)

    endpoint = "#{config.base_url}/api/chat"

    [
      url: endpoint,
      json: body,
      headers: [{"Content-Type", "application/json"}],
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
        {:error, {status, inspect(body)}}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, :ollama_not_running}

      {:error, error} ->
        handle_error(error)
    end
  end

  # ---------------------------------------------------------------------------
  # Model Management
  # ---------------------------------------------------------------------------

  @doc """
  Lists all locally available models.

  Returns a list of model info maps with keys like `"name"`, `"size"`,
  `"digest"`, `"modified_at"`, and `"details"`.

  ## Options
  - `:base_url` - Ollama server URL (default: http://localhost:11434)
  """
  @spec list_models(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_models(opts \\ []) do
    base_url = opts[:base_url] || resolve_base_url()

    [
      url: "#{base_url}/api/tags",
      headers: [{"Content-Type", "application/json"}],
      retry: false
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, models}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, inspect(body)}}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, :ollama_not_running}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Pulls (downloads) a model from the Ollama library.

  This is a blocking operation that waits for the download to complete.

  ## Examples

      Lux.LLM.Ollama.pull_model("llama3.2:latest")
      Lux.LLM.Ollama.pull_model("codellama:7b", base_url: "http://remote:11434")
  """
  @spec pull_model(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def pull_model(model_name, opts \\ []) do
    base_url = opts[:base_url] || resolve_base_url()

    [
      url: "#{base_url}/api/pull",
      json: %{name: model_name, stream: false},
      headers: [{"Content-Type", "application/json"}],
      receive_timeout: :infinity,
      retry: false
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: %{"error" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, inspect(body)}}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, :ollama_not_running}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Shows information about a locally available model.

  Returns details including modelfile, parameters, template, and license.

  ## Examples

      Lux.LLM.Ollama.show_model("llama3.2:latest")
  """
  @spec show_model(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def show_model(model_name, opts \\ []) do
    base_url = opts[:base_url] || resolve_base_url()

    [
      url: "#{base_url}/api/show",
      json: %{name: model_name},
      headers: [{"Content-Type", "application/json"}],
      retry: false
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404, body: _body}} ->
        {:error, :model_not_found}

      {:ok, %{status: status, body: %{"error" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, inspect(body)}}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, :ollama_not_running}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Deletes a locally available model.

  ## Examples

      Lux.LLM.Ollama.delete_model("llama3.2:latest")
  """
  @spec delete_model(String.t(), keyword()) :: :ok | {:error, term()}
  def delete_model(model_name, opts \\ []) do
    base_url = opts[:base_url] || resolve_base_url()

    [
      url: "#{base_url}/api/delete",
      json: %{name: model_name},
      headers: [{"Content-Type", "application/json"}],
      retry: false
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request(method: :delete)
    |> case do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: 404}} ->
        {:error, :model_not_found}

      {:ok, %{status: status, body: %{"error" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, inspect(body)}}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, :ollama_not_running}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Ensures a model is available locally, pulling it if necessary.

  First checks if the model exists locally via `show_model/2`.
  If not found, pulls it via `pull_model/2`.

  ## Examples

      Lux.LLM.Ollama.ensure_model("llama3.2:latest")
  """
  @spec ensure_model(String.t(), keyword()) :: {:ok, :already_available | :pulled} | {:error, term()}
  def ensure_model(model_name, opts \\ []) do
    case show_model(model_name, opts) do
      {:ok, _info} ->
        {:ok, :already_available}

      {:error, :model_not_found} ->
        case pull_model(model_name, opts) do
          {:ok, _} -> {:ok, :pulled}
          error -> error
        end

      error ->
        error
    end
  end

  @doc """
  Checks if the Ollama server is running and accessible.

  ## Examples

      Lux.LLM.Ollama.health_check()
      Lux.LLM.Ollama.health_check(base_url: "http://remote:11434")
  """
  @spec health_check(keyword()) :: {:ok, :healthy} | {:error, term()}
  def health_check(opts \\ []) do
    base_url = opts[:base_url] || resolve_base_url()

    [url: base_url, retry: false]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200}} ->
        {:ok, :healthy}

      {:ok, %{status: status}} ->
        {:error, {status, "Unexpected status from Ollama server"}}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, :ollama_not_running}

      {:error, error} ->
        {:error, error}
    end
  end

  # ---------------------------------------------------------------------------
  # Private - Config building
  # ---------------------------------------------------------------------------

  defp build_config(config) do
    defaults = %{
      model: resolve_model(),
      base_url: resolve_base_url()
    }

    struct(Config, Map.merge(defaults, config))
  end

  defp resolve_base_url do
    System.get_env("OLLAMA_BASE_URL") ||
      Application.get_env(:lux, __MODULE__)[:base_url] ||
      @default_base_url
  end

  defp resolve_model do
    System.get_env("OLLAMA_MODEL") ||
      (Application.get_env(:lux, :ollama_models) || [])[:default] ||
      @default_model
  end

  # ---------------------------------------------------------------------------
  # Private - Message building
  # ---------------------------------------------------------------------------

  defp build_messages(prompt, nil) do
    [%{role: "user", content: prompt}]
  end

  defp build_messages(prompt, system) do
    [%{role: "system", content: system}, %{role: "user", content: prompt}]
  end

  # ---------------------------------------------------------------------------
  # Private - Ollama options
  # ---------------------------------------------------------------------------

  defp add_options(body, config) do
    options =
      %{}
      |> maybe_put(:temperature, config.temperature)
      |> maybe_put(:num_ctx, config.num_ctx)
      |> maybe_put(:num_gpu, config.num_gpu)
      |> maybe_put(:num_predict, config.num_predict)
      |> maybe_put(:top_p, config.top_p)
      |> maybe_put(:top_k, config.top_k)
      |> maybe_put(:seed, config.seed)

    body
    |> Map.put(:options, options)
    |> maybe_put(:keep_alive, config.keep_alive)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # ---------------------------------------------------------------------------
  # Private - Tools
  # ---------------------------------------------------------------------------

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  @doc false
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
        parameters: build_tool_parameters(input_schema)
      }
    }
  end

  def tool_to_function(%Prism{module_name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: build_tool_parameters(input_schema)
      }
    }
  end

  def tool_to_function(%Lens{module_name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: build_tool_parameters(schema)
      }
    }
  end

  # Ollama expects JSON Schema style parameters with string type keys
  defp build_tool_parameters(schema) when is_map(schema) do
    schema
    |> normalize_schema_types()
  end

  defp normalize_schema_types(schema) when is_map(schema) do
    Enum.into(schema, %{}, fn
      {:type, type} when is_atom(type) -> {:type, Atom.to_string(type)}
      {key, value} when is_map(value) -> {key, normalize_schema_types(value)}
      pair -> pair
    end)
  end

  defp normalize_schema_types(value), do: value

  # ---------------------------------------------------------------------------
  # Private - Response format
  # ---------------------------------------------------------------------------

  defp maybe_add_format(body, %Config{json_response: true}, []) do
    Map.put(body, :format, "json")
  end

  defp maybe_add_format(body, _config, _tools), do: body

  # ---------------------------------------------------------------------------
  # Private - Response handling
  # ---------------------------------------------------------------------------

  defp handle_response(%{body: body}, _config) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> process_response(decoded)
      {:error, _} -> {:error, "Failed to decode Ollama response"}
    end
  end

  defp handle_response(%{body: body}, _config) when is_map(body) do
    process_response(body)
  end

  defp process_response(body) do
    message = body["message"] || %{}
    content_raw = message["content"]
    tool_calls_raw = message["tool_calls"]

    with {:ok, content} <- parse_content(content_raw),
         {:ok, tool_calls_results} <- execute_tool_calls(tool_calls_raw) do
      # Determine finish reason from Ollama's done_reason or done flag
      finish_reason =
        body["done_reason"] ||
          if(body["done"] == true, do: "stop", else: "unknown")

      # Build performance metadata from Ollama's timing info
      metadata = %{
        id: nil,
        created: nil,
        usage: build_usage(body),
        system_fingerprint: nil,
        performance: build_performance(body)
      }

      payload = %{
        content: content,
        model: body["model"],
        finish_reason: finish_reason,
        tool_calls: format_tool_calls_for_signal(tool_calls_raw),
        tool_calls_results: tool_calls_results
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

  # Format Ollama-style tool calls to match the ResponseSignal schema
  defp format_tool_calls_for_signal(nil), do: nil
  defp format_tool_calls_for_signal([]), do: nil

  defp format_tool_calls_for_signal(tool_calls) when is_list(tool_calls) do
    Enum.map(tool_calls, fn
      %{"function" => %{"name" => name, "arguments" => args}} ->
        %{
          "type" => "function",
          "function" => %{
            "name" => name,
            "arguments" => if(is_binary(args), do: args, else: Jason.encode!(args))
          }
        }
    end)
  end

  defp build_usage(body) do
    %{
      "prompt_tokens" => body["prompt_eval_count"],
      "completion_tokens" => body["eval_count"],
      "total_tokens" =>
        (body["prompt_eval_count"] || 0) + (body["eval_count"] || 0)
    }
  end

  defp build_performance(body) do
    %{
      total_duration_ns: body["total_duration"],
      load_duration_ns: body["load_duration"],
      prompt_eval_duration_ns: body["prompt_eval_duration"],
      eval_duration_ns: body["eval_duration"],
      prompt_eval_count: body["prompt_eval_count"],
      eval_count: body["eval_count"],
      tokens_per_second: calculate_tokens_per_second(body)
    }
  end

  defp calculate_tokens_per_second(%{"eval_count" => count, "eval_duration" => duration})
       when is_number(count) and is_number(duration) and duration > 0 do
    Float.round(count / (duration / 1_000_000_000), 2)
  end

  defp calculate_tokens_per_second(_), do: nil

  # ---------------------------------------------------------------------------
  # Private - Content parsing
  # ---------------------------------------------------------------------------

  @doc false
  def parse_content(nil), do: {:ok, nil}
  def parse_content(""), do: {:ok, nil}

  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} -> {:ok, structured_output}
      {:error, _} -> {:ok, %{"text" => content}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private - Tool execution
  # ---------------------------------------------------------------------------

  @doc false
  def execute_tool_calls(nil), do: {:ok, nil}
  def execute_tool_calls([]), do: {:ok, []}

  def execute_tool_calls(tool_calls) when is_list(tool_calls) do
    tool_calls
    |> Enum.map(&execute_tool_call/1)
    |> Enum.reduce({:ok, []}, fn
      {:ok, result, _log}, {:ok, results} -> {:ok, [result | results]}
      {:ok, result}, {:ok, results} -> {:ok, [result | results]}
      error, _ -> error
    end)
  end

  defp execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
    decoded_args =
      cond do
        is_map(args) -> args
        is_binary(args) -> Jason.decode!(args)
        true -> %{}
      end

    execute_tool(tool_name, decoded_args, nil)
  end

  @doc false
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
         "Failed to load tool module #{tool_name}: module not found or not reachable"}

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
         Tool #{tool_module} does not seem to be a valid Beam, Prism, or Lens
         as it does not have a registered handler, run, or focus function.
         """}
    end
  end

  # ---------------------------------------------------------------------------
  # Private - Error handling
  # ---------------------------------------------------------------------------

  defp handle_error(error) do
    Logger.error("Ollama API error: #{inspect(error)}")
    {:error, "Ollama API error: #{inspect(error)}"}
  end
end
