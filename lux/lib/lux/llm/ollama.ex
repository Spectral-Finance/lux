defmodule Lux.LLM.Ollama do
  @moduledoc """
  Local LLM implementation using Ollama (http://localhost:11434).

  Features:
  - Implements the `Lux.LLM` behaviour.
  - Native function calling / tool use with Beams, Prisms, and Lenses.
  - Fine-grained hardware & resource controls (`num_ctx`, `num_gpu`, `num_thread`, `num_predict`).
  - Model caching and memory management via `keep_alive`.
  - Detailed inference telemetry (tokens/sec, prompt eval latency, VRAM utilization).
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.Ollama.ModelManager
  alias Lux.LLM.Ollama.ResourceMonitor
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @default_endpoint "http://localhost:11434"
  @default_model "llama3.2"

  defmodule Config do
    @moduledoc """
    Configuration struct for local Ollama inference requests.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            temperature: float(),
            top_p: float(),
            top_k: integer() | nil,
            num_ctx: integer(),
            num_predict: integer() | nil,
            num_gpu: integer() | nil,
            num_thread: integer() | nil,
            repeat_penalty: float() | nil,
            stop: list(String.t()),
            messages: list(map()),
            keep_alive: String.t() | integer() | nil,
            format: String.t() | map() | nil,
            timeout: non_neg_integer()
          }

    defstruct endpoint: "http://localhost:11434",
              model: "llama3.2",
              temperature: 0.7,
              top_p: 0.9,
              top_k: 40,
              num_ctx: 4096,
              num_predict: nil,
              num_gpu: nil,
              num_thread: nil,
              repeat_penalty: 1.1,
              stop: [],
              messages: [],
              keep_alive: "5m",
              format: nil,
              timeout: 120_000
  end

  @impl true
  def call(prompt, tools, config) do
    config = build_config(config)

    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    options =
      %{
        temperature: config.temperature,
        top_p: config.top_p,
        num_ctx: config.num_ctx
      }
      |> maybe_add(:top_k, config.top_k)
      |> maybe_add(:num_predict, config.num_predict)
      |> maybe_add(:num_gpu, config.num_gpu)
      |> maybe_add(:num_thread, config.num_thread)
      |> maybe_add(:repeat_penalty, config.repeat_penalty)
      |> maybe_add(:stop, (config.stop != [] && config.stop) || nil)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        stream: false,
        options: options
      }
      |> maybe_add(:keep_alive, config.keep_alive)
      |> maybe_add(:format, config.format)
      |> maybe_add_tools(tools_config)

    url = "#{config.endpoint}/api/chat"

    [
      url: url,
      json: body,
      headers: [{"Content-Type", "application/json"}],
      receive_timeout: config.timeout
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> handle_response(config)
  end

  @doc """
  Runs direct chat completion with local model.
  """
  def chat(prompt, opts \\ []) do
    config = Map.new(opts)
    call(prompt, [], config)
  end

  @doc """
  Preloads a model into VRAM/RAM with a custom `keep_alive` window (e.g. "10m", "-1" for indefinitely).
  """
  def preload_model(model_name, keep_alive \\ "10m", opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, @default_endpoint)
    url = "#{endpoint}/api/generate"

    body = %{
      model: model_name,
      keep_alive: keep_alive
    }

    [
      url: url,
      json: body,
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200}} -> {:ok, :preloaded}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Unloads a model from memory immediately by setting `keep_alive` to 0.
  """
  def unload_model(model_name, opts \\ []) do
    preload_model(model_name, 0, opts)
  end

  # Helpers & Tool Calling
  defp build_config(config) when is_map(config) do
    default_model =
      case Application.get_env(:lux, :ollama_models) do
        models when is_list(models) -> Keyword.get(models, :default, @default_model)
        _ -> @default_model
      end

    endpoint =
      case Application.get_env(:lux, :ollama) do
        opts when is_list(opts) -> Keyword.get(opts, :endpoint, @default_endpoint)
        opts when is_map(opts) -> Map.get(opts, :endpoint, @default_endpoint)
        _ -> @default_endpoint
      end

    struct(
      Config,
      Map.merge(
        %{
          model: default_model,
          endpoint: endpoint
        },
        config
      )
    )
  end
  defp build_config(config) when is_list(config), do: build_config(Map.new(config))

  defp build_messages(prompt) when is_binary(prompt), do: [%{role: "user", content: prompt}]
  defp build_messages(messages) when is_list(messages), do: messages
  defp build_messages(_), do: []

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, val), do: Map.put(map, key, val)

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

  def tool_to_function(%Beam{name: name, description: description, input_schema: input_schema}) do
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

  def tool_to_function(%Lens{name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: name || "unnamed_lens",
        description: description || "",
        parameters: schema
      }
    }
  end

  # Response Parsing
  defp handle_response({:ok, %{status: 200, body: body}}, _config) do
    message = body["message"] || %{}
    content = parse_content(message["content"])
    tool_calls = message["tool_calls"]

    case execute_tool_calls(tool_calls) do
      {:ok, tool_calls_results} ->
        payload = %{
          content: content,
          model: body["model"],
          finish_reason: body["done_reason"] || "stop",
          tool_calls: tool_calls,
          tool_calls_results: tool_calls_results
        }

        metrics = ResourceMonitor.parse_metrics(body)

        metadata = %{
          created_at: body["created_at"],
          done: body["done"],
          metrics: metrics,
          usage: %{
            "prompt_tokens" => metrics.prompt_tokens,
            "completion_tokens" => metrics.eval_tokens,
            "total_tokens" => metrics.total_tokens
          }
        }

        %{
          schema_id: ResponseSignal,
          payload: payload,
          metadata: metadata
        }
        |> Lux.Signal.new()
        |> ResponseSignal.validate()

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_response({:ok, %{status: 404, body: %{"error" => error}}}, config) do
    {:error, {:model_not_found, "Model '#{config.model}' is not installed in Ollama. Error: #{error}"}}
  end

  defp handle_response({:ok, %{status: status, body: body}}, _config) do
    {:error, {status, body}}
  end

  defp handle_response({:error, %Req.TransportError{reason: :econnrefused}}, _config) do
    {:error, :ollama_connection_refused}
  end

  defp handle_response({:error, reason}, _config) do
    Logger.error("Ollama API request failed: #{inspect(reason)}")
    {:error, reason}
  end

  def parse_content(nil), do: nil
  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured} -> structured
      {:error, _} -> content
    end
  end
  def parse_content(other), do: other

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

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
    parsed_args =
      case args do
        str when is_binary(str) ->
          case Jason.decode(str) do
            {:ok, m} -> m
            _ -> %{}
          end
        m when is_map(m) -> m
        _ -> %{}
      end

    execute_tool(tool_name, parsed_args, nil)
  end
  def execute_tool_call(_), do: {:ok, nil}

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
        {:error, "Failed to load tool module #{tool_name}: module not found"}

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

      true ->
        {:error, "Tool #{tool_module} is not a valid Beam or Prism"}
    end
  end
end
