defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation for local model inference (`Lux.LLM` behaviour).

  Supports:
  - Chat completions (`/api/chat`) and text generation (`/api/generate`)
  - Local vector embeddings (`/api/embeddings` and `/api/embed`)
  - Function / tool calling for `Lux.Beam`, `Lux.Prism`, and `Lux.Lens`
  - Structured JSON output and schema enforcement
  - Hardware resource controls (`num_ctx`, `num_gpu`, `num_thread`, `keep_alive`)
  - Automatic model availability check and telemetry via `Lux.LLM.Ollama.ModelManager`
  """

  @behaviour Lux.LLM

  require Logger

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.Ollama.ModelManager
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  @default_endpoint "http://localhost:11434"
  @default_receive_timeout 120_000

  defmodule Config do
    @moduledoc """
    Configuration struct for `Lux.LLM.Ollama`.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            stream: boolean(),
            temperature: float(),
            top_p: float() | nil,
            top_k: integer() | nil,
            num_ctx: pos_integer() | nil,
            num_gpu: non_neg_integer() | nil,
            num_thread: pos_integer() | nil,
            repeat_penalty: float() | nil,
            seed: integer() | nil,
            stop: [String.t()] | nil,
            keep_alive: String.t() | integer(),
            format: String.t() | map() | nil,
            json_response: boolean(),
            json_schema: map() | nil,
            auto_pull: boolean(),
            receive_timeout: pos_integer(),
            messages: [map()],
            user: String.t() | nil
          }

    defstruct endpoint: "http://localhost:11434",
              model: "llama3.2",
              stream: false,
              temperature: 0.7,
              top_p: nil,
              top_k: nil,
              num_ctx: 4096,
              num_gpu: nil,
              num_thread: nil,
              repeat_penalty: nil,
              seed: nil,
              stop: nil,
              keep_alive: "5m",
              format: nil,
              json_response: false,
              json_schema: nil,
              auto_pull: false,
              receive_timeout: 120_000,
              messages: [],
              user: nil
  end

  @impl Lux.LLM
  def call(prompt, tools, config) when is_map(config) do
    resolved_config = build_config(config)

    if resolved_config.auto_pull do
      _ = ModelManager.ensure_model(resolved_config.model, endpoint: resolved_config.endpoint)
    end

    messages = build_messages(prompt, resolved_config)
    tools_payload = Enum.map(tools || [], &tool_to_function/1)
    options_payload = build_options(resolved_config)

    body =
      %{
        model: resolved_config.model,
        messages: messages,
        stream: resolved_config.stream,
        keep_alive: resolved_config.keep_alive
      }
      |> maybe_put(:options, options_payload)
      |> maybe_put_tools(tools_payload)
      |> maybe_put_format(resolved_config)

    req_opts =
      [
        url: "#{String.trim_trailing(resolved_config.endpoint, "/")}/api/chat",
        json: body,
        headers: [{"content-type", "application/json"}, {"accept", "application/json"}],
        receive_timeout: resolved_config.receive_timeout
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    req_opts
    |> Req.new()
    |> Req.Request.run_request()
    |> handle_chat_response(resolved_config)
  end

  def call(prompt, tools, config) when is_list(config) do
    call(prompt, tools, Enum.into(config, %{}))
  end

  @doc """
  Generates text completions using Ollama's `/api/generate` endpoint.
  """
  @spec generate(String.t(), map() | keyword()) :: {:ok, Lux.Signal.t()} | {:error, term()}
  def generate(prompt, config \\ %{}) do
    resolved_config = build_config(config)

    body =
      %{
        model: resolved_config.model,
        prompt: prompt,
        stream: false,
        keep_alive: resolved_config.keep_alive
      }
      |> maybe_put(:options, build_options(resolved_config))
      |> maybe_put_format(resolved_config)

    req_opts =
      [
        url: "#{String.trim_trailing(resolved_config.endpoint, "/")}/api/generate",
        json: body,
        headers: [{"content-type", "application/json"}],
        receive_timeout: resolved_config.receive_timeout
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    req_opts
    |> Req.new()
    |> Req.Request.run_request()
    |> handle_generate_response(resolved_config)
  end

  @doc """
  Generates vector embeddings for the given input text or list of strings via `/api/embeddings`.
  """
  @spec embeddings(String.t() | [String.t()], map() | keyword()) ::
          {:ok, %{embeddings: list(), model: String.t(), metadata: map()}} | {:error, term()}
  def embeddings(input, config \\ %{}) do
    resolved_config = build_config(config)

    body =
      %{
        model: resolved_config.model,
        prompt: if(is_list(input), do: Enum.join(input, "\n"), else: input)
      }
      |> maybe_put(:options, build_options(resolved_config))
      |> maybe_put(:keep_alive, resolved_config.keep_alive)

    req_opts =
      [
        url: "#{String.trim_trailing(resolved_config.endpoint, "/")}/api/embeddings",
        json: body,
        headers: [{"content-type", "application/json"}],
        receive_timeout: resolved_config.receive_timeout
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    case req_opts |> Req.new() |> Req.Request.run_request() do
      {_req, %Req.Response{status: 200, body: %{"embedding" => vector} = resp_body}} ->
        {:ok,
         %{
           embeddings: vector,
           model: Map.get(resp_body, "model", resolved_config.model),
           metadata: extract_metrics(resp_body)
         }}

      {_req, %Req.Response{status: 200, body: %{"embeddings" => vectors} = resp_body}} ->
        {:ok,
         %{
           embeddings: vectors,
           model: Map.get(resp_body, "model", resolved_config.model),
           metadata: extract_metrics(resp_body)
         }}

      {_req, %Req.Response{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {_req, error} ->
        {:error, error}
    end
  end

  @doc """
  Converts a Lux `Beam`, `Prism`, or `Lens` into an Ollama-compatible tool specification.
  """
  def tool_to_function(%Beam{} = beam) do
    %{
      type: "function",
      function: %{
        name: String.replace(beam.name, " ", "_"),
        description: beam.description,
        parameters: beam.input_schema
      }
    }
  end

  def tool_to_function(%Prism{} = prism) do
    %{
      type: "function",
      function: %{
        name: String.replace(prism.name, " ", "_"),
        description: prism.description,
        parameters: prism.input_schema
      }
    }
  end

  def tool_to_function(%Lens{} = lens) do
    %{
      type: "function",
      function: %{
        name: String.replace(lens.name, " ", "_"),
        description: lens.description,
        parameters: lens.schema
      }
    }
  end

  def tool_to_function(module) when is_atom(module) do
    cond do
      function_exported?(module, :view, 0) -> tool_to_function(module.view())
      true -> raise ArgumentError, "Unsupported tool module #{inspect(module)}"
    end
  end

  def tool_to_function(%{"type" => "function"} = raw_tool), do: raw_tool
  def tool_to_function(%{type: "function"} = raw_tool), do: raw_tool

  @doc """
  Builds a normalized `%Lux.LLM.Ollama.Config{}` from user options and application environment.
  """
  @spec build_config(map() | keyword()) :: Config.t()
  def build_config(config) when is_list(config) do
    config |> Enum.into(%{}) |> build_config()
  end

  def build_config(%Config{} = config), do: config

  def build_config(config) when is_map(config) do
    app_defaults = Application.get_env(:lux, :ollama_config, %{}) |> Enum.into(%{})
    default_model = Application.get_env(:lux, :ollama_models, %{})[:default] || "llama3.2"
    default_endpoint = System.get_env("OLLAMA_ENDPOINT", @default_endpoint)

    merged =
      %{
        endpoint: default_endpoint,
        model: default_model,
        receive_timeout: @default_receive_timeout
      }
      |> Map.merge(app_defaults)
      |> Map.merge(config)

    struct(Config, merged)
  end

  defp build_messages(prompt, %Config{messages: messages}) when is_list(messages) do
    messages ++ [%{role: "user", content: prompt}]
  end

  defp build_options(%Config{} = config) do
    %{}
    |> maybe_put(:temperature, config.temperature)
    |> maybe_put(:top_p, config.top_p)
    |> maybe_put(:top_k, config.top_k)
    |> maybe_put(:num_ctx, config.num_ctx)
    |> maybe_put(:num_gpu, config.num_gpu)
    |> maybe_put(:num_thread, config.num_thread)
    |> maybe_put(:repeat_penalty, config.repeat_penalty)
    |> maybe_put(:seed, config.seed)
    |> maybe_put(:stop, config.stop)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, empty) when empty == %{}, do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_tools(body, []), do: body
  defp maybe_put_tools(body, tools), do: Map.put(body, :tools, tools)

  defp maybe_put_format(body, %Config{json_schema: schema}) when is_map(schema) do
    Map.put(body, :format, schema)
  end

  defp maybe_put_format(body, %Config{format: format}) when not is_nil(format) do
    Map.put(body, :format, format)
  end

  defp maybe_put_format(body, %Config{json_response: true}) do
    Map.put(body, :format, "json")
  end

  defp maybe_put_format(body, _config), do: body

  defp handle_chat_response({_req, %Req.Response{status: 200, body: body}}, config)
       when is_map(body) do
    metrics = extract_metrics(body)
    ModelManager.record_metrics(config.model, metrics)

    message = Map.get(body, "message", %{})
    tool_calls = Map.get(message, "tool_calls", [])
    raw_content = Map.get(message, "content", "")

    parsed_content = decode_content(raw_content, config)

    payload = %{
      content: parsed_content,
      model: Map.get(body, "model", config.model),
      finish_reason: normalize_finish_reason(body, tool_calls),
      tool_calls: normalize_tool_calls(tool_calls),
      tool_calls_results: nil,
      usage: %{
        prompt_tokens: Map.get(body, "prompt_eval_count", 0),
        completion_tokens: Map.get(body, "eval_count", 0),
        total_tokens:
          Map.get(body, "prompt_eval_count", 0) + Map.get(body, "eval_count", 0)
      }
    }

    {:ok,
     Lux.Signal.new(%{
       schema_id: ResponseSignal,
       payload: payload,
       metadata:
         Map.merge(metrics, %{
           provider: :ollama,
           endpoint: config.endpoint,
           created_at: Map.get(body, "created_at")
         })
     })}
  end

  defp handle_chat_response({_req, %Req.Response{status: status, body: body}}, _config) do
    {:error, {:http_error, status, body}}
  end

  defp handle_chat_response({_req, error}, _config) do
    {:error, error}
  end

  defp handle_generate_response({_req, %Req.Response{status: 200, body: body}}, config)
       when is_map(body) do
    metrics = extract_metrics(body)
    ModelManager.record_metrics(config.model, metrics)

    raw_response = Map.get(body, "response", "")
    parsed_content = decode_content(raw_response, config)

    payload = %{
      content: parsed_content,
      model: Map.get(body, "model", config.model),
      finish_reason: Map.get(body, "done_reason", "stop"),
      tool_calls: nil,
      tool_calls_results: nil,
      usage: %{
        prompt_tokens: Map.get(body, "prompt_eval_count", 0),
        completion_tokens: Map.get(body, "eval_count", 0),
        total_tokens:
          Map.get(body, "prompt_eval_count", 0) + Map.get(body, "eval_count", 0)
      }
    }

    {:ok,
     Lux.Signal.new(%{
       schema_id: ResponseSignal,
       payload: payload,
       metadata: Map.merge(metrics, %{provider: :ollama, endpoint: config.endpoint})
     })}
  end

  defp handle_generate_response({_req, %Req.Response{status: status, body: body}}, _config) do
    {:error, {:http_error, status, body}}
  end

  defp handle_generate_response({_req, error}, _config) do
    {:error, error}
  end

  defp decode_content(content, %Config{json_response: json_resp, format: format, json_schema: schema})
       when is_binary(content) do
    trimmed = String.trim(content)

    cond do
      trimmed == "" ->
        ""

      json_resp or format == "json" or is_map(format) or is_map(schema) or
          String.starts_with?(trimmed, "{") or String.starts_with?(trimmed, "[") ->
        case Jason.decode(trimmed) do
          {:ok, decoded} -> decoded
          {:error, _} -> content
        end

      true ->
        content
    end
  end

  defp decode_content(content, _config), do: content

  defp normalize_finish_reason(_body, tool_calls) when is_list(tool_calls) and tool_calls != [] do
    "tool_calls"
  end

  defp normalize_finish_reason(body, _tool_calls) do
    Map.get(body, "done_reason", "stop")
  end

  defp normalize_tool_calls([]), do: nil
  defp normalize_tool_calls(nil), do: nil

  defp normalize_tool_calls(tool_calls) when is_list(tool_calls) do
    Enum.map(tool_calls, fn tc ->
      func = Map.get(tc, "function", %{})
      args = Map.get(func, "arguments", %{})

      normalized_args =
        cond do
          is_binary(args) ->
            case Jason.decode(args) do
              {:ok, decoded} -> decoded
              _ -> %{"raw" => args}
            end

          is_map(args) ->
            args

          true ->
            %{}
        end

      %{
        "type" => "function",
        "function" => %{
          "name" => Map.get(func, "name"),
          "arguments" => normalized_args
        }
      }
    end)
  end

  @doc """
  Extracts timing and token-throughput telemetry from an Ollama response map.
  """
  @spec extract_metrics(map()) :: map()
  def extract_metrics(body) when is_map(body) do
    total_ns = Map.get(body, "total_duration", 0)
    load_ns = Map.get(body, "load_duration", 0)
    prompt_eval_ns = Map.get(body, "prompt_eval_duration", 0)
    eval_ns = Map.get(body, "eval_duration", 0)
    eval_count = Map.get(body, "eval_count", 0)
    prompt_eval_count = Map.get(body, "prompt_eval_count", 0)

    tokens_per_second =
      if is_number(eval_ns) and eval_ns > 0 and is_number(eval_count) do
        Float.round(eval_count / (eval_ns / 1_000_000_000), 2)
      else
        0.0
      end

    %{
      total_duration_ms: ns_to_ms(total_ns),
      load_duration_ms: ns_to_ms(load_ns),
      prompt_eval_duration_ms: ns_to_ms(prompt_eval_ns),
      eval_duration_ms: ns_to_ms(eval_ns),
      prompt_eval_count: prompt_eval_count,
      eval_count: eval_count,
      tokens_per_second: tokens_per_second
    }
  end

  defp ns_to_ms(ns) when is_number(ns) and ns > 0, do: Float.round(ns / 1_000_000, 2)
  defp ns_to_ms(_), do: 0.0
end
