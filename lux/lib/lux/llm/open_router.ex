defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation supporting access to dozens of leading LLM providers
  (Anthropic, OpenAI, Meta Llama, Google Gemini, Mistral, DeepSeek) through a single unified API.

  Features:
  - Unified `Lux.LLM` behaviour implementation.
  - Automatic tool calling for Beams, Prisms, and Lenses.
  - Multi-model fallback cascades natively supported by OpenRouter (`models: [...]`).
  - Account key & quota inspection (`/api/v1/auth/key`).
  - Automatic token cost tracking and estimation.
  - Exponential backoff retry logic for transient errors (429 rate limit, 502/503 provider outages).
  - OpenRouter attribution headers (`HTTP-Referer`, `X-Title`).
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.OpenRouter.KeyLimits
  alias Lux.LLM.OpenRouter.ModelRouter
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @default_endpoint "https://openrouter.ai/api/v1/chat/completions"
  @default_referer "https://lux.agent"
  @default_title "Lux Agent"

  defmodule Config do
    @moduledoc """
    Configuration struct for OpenRouter requests.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            models: list(String.t()),
            api_key: String.t() | nil,
            temperature: float(),
            top_p: float(),
            top_k: integer() | nil,
            max_tokens: integer() | nil,
            repetition_penalty: float() | nil,
            frequency_penalty: float() | nil,
            presence_penalty: float() | nil,
            stop: list(String.t()),
            messages: list(map()),
            route: String.t() | nil,
            provider: map() | nil,
            transforms: list(String.t()) | nil,
            http_referer: String.t(),
            x_title: String.t(),
            max_retries: non_neg_integer(),
            retry_backoff_ms: non_neg_integer()
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: "anthropic/claude-3.5-sonnet",
              models: [],
              api_key: nil,
              temperature: 0.7,
              top_p: 0.9,
              top_k: nil,
              max_tokens: nil,
              repetition_penalty: nil,
              frequency_penalty: nil,
              presence_penalty: nil,
              stop: [],
              messages: [],
              route: nil,
              provider: nil,
              transforms: nil,
              http_referer: "https://lux.agent",
              x_title: "Lux Agent",
              max_retries: 3,
              retry_backoff_ms: 500
  end

  @impl true
  def call(prompt, tools, config) do
    config = build_config(config)

    case validate_api_key(config.api_key) do
      {:ok, api_key} ->
        config = %{config | api_key: api_key}
        messages = config.messages ++ build_messages(prompt)
        tools_config = build_tools_config(tools)

        body =
          %{
            model: Lux.Config.resolve(config.model),
            messages: messages,
            temperature: config.temperature,
            top_p: config.top_p
          }
          |> maybe_add_optional(:max_tokens, config.max_tokens)
          |> maybe_add_optional(:top_k, config.top_k)
          |> maybe_add_optional(:repetition_penalty, config.repetition_penalty)
          |> maybe_add_optional(:frequency_penalty, config.frequency_penalty)
          |> maybe_add_optional(:presence_penalty, config.presence_penalty)
          |> maybe_add_optional(:stop, (config.stop != [] && config.stop) || nil)
          |> maybe_add_optional(:models, (config.models != [] && config.models) || nil)
          |> maybe_add_optional(:route, config.route)
          |> maybe_add_optional(:provider, config.provider)
          |> maybe_add_optional(:transforms, config.transforms)
          |> maybe_add_tools(tools_config)

        headers = [
          {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
          {"HTTP-Referer", config.http_referer},
          {"X-Title", config.x_title},
          {"Content-Type", "application/json"}
        ]

        req_opts =
          [
            url: config.endpoint,
            json: body,
            headers: headers
          ]
          |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

        execute_with_retries(req_opts, config.max_retries, config.retry_backoff_ms, config)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Direct convenience function to run text completion.
  """
  def chat(prompt, opts \\ []) do
    config = Map.new(opts)
    call(prompt, [], config)
  end

  @doc """
  Queries key limits and credit usage for the OpenRouter key.
  """
  def key_limits(opts \\ []) do
    api_key = Keyword.get(opts, :api_key)
    KeyLimits.get_key_info(api_key, opts)
  end

  @doc """
  Lists models available via OpenRouter API.
  """
  def list_models(opts \\ []) do
    ModelRouter.fetch_remote_models(opts)
  end

  # ============================================================================
  # Internal Helpers
  # ============================================================================

  defp build_config(config) when is_map(config) do
    default_model =
      case Application.get_env(:lux, :openrouter_models) do
        models when is_list(models) -> Keyword.get(models, :default, "anthropic/claude-3.5-sonnet")
        _ -> "anthropic/claude-3.5-sonnet"
      end

    default_key =
      case Application.get_env(:lux, :api_keys) do
        keys when is_list(keys) -> Keyword.get(keys, :openrouter)
        keys when is_map(keys) -> Map.get(keys, :openrouter)
        _ -> nil
      end || System.get_env("OPENROUTER_API_KEY")

    struct(
      Config,
      Map.merge(
        %{
          model: default_model,
          api_key: default_key,
          endpoint: @default_endpoint,
          http_referer: @default_referer,
          x_title: @default_title
        },
        config
      )
    )
  end
  defp build_config(config) when is_list(config), do: build_config(Map.new(config))

  defp validate_api_key(nil), do: {:error, :missing_api_key}
  defp validate_api_key(""), do: {:error, :missing_api_key}
  defp validate_api_key("missing openrouter"), do: {:error, :missing_api_key}
  defp validate_api_key(key) when is_binary(key), do: {:ok, key}

  defp build_messages(prompt) when is_binary(prompt), do: [%{role: "user", content: prompt}]
  defp build_messages(messages) when is_list(messages), do: messages
  defp build_messages(_), do: []

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  defp maybe_add_optional(map, _key, nil), do: map
  defp maybe_add_optional(map, key, val), do: Map.put(map, key, val)

  # Tool definitions
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

  # Execution and Retries
  defp execute_with_retries(req_opts, retries_left, backoff_ms, config) do
    req_opts
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: 402, body: body}} ->
        {:error, {:insufficient_credits, body}}

      {:ok, %{status: 429, body: body}} when retries_left > 0 ->
        Logger.warning("OpenRouter rate limited (429). Retrying in #{backoff_ms}ms... Body: #{inspect(body)}")
        :timer.sleep(backoff_ms)
        execute_with_retries(req_opts, retries_left - 1, backoff_ms * 2, config)

      {:ok, %{status: status, body: body}} when status in [502, 503, 504] and retries_left > 0 ->
        Logger.warning("OpenRouter server error (#{status}). Retrying in #{backoff_ms}ms... Body: #{inspect(body)}")
        :timer.sleep(backoff_ms)
        execute_with_retries(req_opts, retries_left - 1, backoff_ms * 2, config)

      {:ok, %{status: status, body: %{"error" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} when retries_left > 0 ->
        Logger.warning("OpenRouter network error: #{inspect(reason)}. Retrying in #{backoff_ms}ms...")
        :timer.sleep(backoff_ms)
        execute_with_retries(req_opts, retries_left - 1, backoff_ms * 2, config)

      {:error, reason} ->
        Logger.error("OpenRouter request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Response Parsing & Signal Generation
  defp handle_response(%{body: body}, _config) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message} <- choice,
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
      payload = %{
        content: content,
        model: body["model"],
        finish_reason: choice["finish_reason"],
        tool_calls: message["tool_calls"],
        tool_calls_results: tool_calls_results
      }

      usage = body["usage"] || %{}
      prompt_tokens = usage["prompt_tokens"] || 0
      completion_tokens = usage["completion_tokens"] || 0
      model_id = body["model"] || "unknown"

      cost_estimate = ModelRouter.estimate_cost(model_id, prompt_tokens, completion_tokens)

      metadata = %{
        id: body["id"],
        created: body["created"],
        usage: usage,
        cost_estimate: cost_estimate,
        system_fingerprint: body["system_fingerprint"]
      }

      %{
        schema_id: ResponseSignal,
        payload: payload,
        metadata: metadata
      }
      |> Lux.Signal.new()
      |> ResponseSignal.validate()
    else
      nil ->
        {:error, "Invalid OpenRouter response structure: missing choices"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_content(nil), do: {:ok, nil}
  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} -> {:ok, structured_output}
      {:error, _} -> {:ok, content}
    end
  end
  def parse_content(other), do: {:ok, other}

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
