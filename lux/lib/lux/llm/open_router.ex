defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation that provides unified access to multiple LLM models
  with automatic routing, retries, cost optimization, and tool calling (`Spectral-Finance/lux#95`).
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @endpoint "https://openrouter.ai/api/v1/chat/completions"

  @model_pricing_per_1k %{
    "openai/gpt-4o" => %{input: 0.0025, output: 0.0100},
    "openai/gpt-4o-mini" => %{input: 0.00015, output: 0.0006},
    "anthropic/claude-3.5-sonnet" => %{input: 0.0030, output: 0.0150},
    "meta-llama/llama-3.1-70b-instruct" => %{input: 0.00035, output: 0.0004},
    "deepseek/deepseek-r1" => %{input: 0.00055, output: 0.00219}
  }

  defmodule Config do
    @moduledoc """
    Configuration struct for OpenRouter API calls.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            fallback_models: [String.t()],
            route: String.t() | nil,
            api_key: String.t() | nil,
            site_url: String.t() | nil,
            app_name: String.t(),
            temperature: float(),
            top_p: float(),
            max_tokens: integer() | nil,
            max_retries: non_neg_integer(),
            messages: [map()],
            user: String.t() | nil
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: "openai/gpt-4o-mini",
              fallback_models: [],
              route: "fallback",
              api_key: nil,
              site_url: "https://spectral.finance",
              app_name: "Lux Agent Framework",
              temperature: 0.7,
              top_p: 1.0,
              max_tokens: nil,
              max_retries: 2,
              messages: [],
              user: nil
  end

  @impl true
  def call(prompt, tools, config) when is_list(config) do
    call(prompt, tools, Map.new(config))
  end

  def call(prompt, tools, config) when is_map(config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :open_router_models, [default: "openai/gpt-4o-mini"])[:default],
            api_key: Application.get_env(:lux, :api_keys, [])[:open_router]
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
        temperature: config.temperature,
        top_p: config.top_p,
        max_tokens: config.max_tokens
      }
      |> maybe_add_fallback_routing(config)
      |> maybe_add_tools(tools_config)

    request_opts =
      [
        url: config.endpoint || @endpoint,
        json: body,
        headers: build_headers(config)
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    execute_with_retry(request_opts, config, config.max_retries)
  end

  defp execute_with_retry(request_opts, config, retries_left) do
    request_opts
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: status}} when status in [429, 502, 503, 504] and retries_left > 0 ->
        Logger.warning("OpenRouter transient status #{status}, retrying (#{retries_left} left)")
        execute_with_retry(request_opts, config, retries_left - 1)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: 402}} ->
        {:error, :insufficient_credits}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        if retries_left > 0 do
          execute_with_retry(request_opts, config, retries_left - 1)
        else
          handle_error(error)
        end
    end
  end

  defp build_headers(config) do
    [
      {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
      {"Content-Type", "application/json"},
      {"HTTP-Referer", config.site_url || "https://spectral.finance"},
      {"X-Title", config.app_name || "Lux"}
    ]
  end

  defp build_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_messages(messages) when is_list(messages), do: messages

  defp maybe_add_fallback_routing(body, %Config{fallback_models: [_ | _] = fallbacks, route: route}) do
    body
    |> Map.put(:models, [body.model | fallbacks])
    |> Map.put(:route, route || "fallback")
  end

  defp maybe_add_fallback_routing(body, _config), do: body

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  @doc """
  Converts a Beam, Prism, or Lens into an OpenRouter-compatible function definition.
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

  @doc """
  Estimates the USD cost of an OpenRouter call from usage metadata and model pricing.
  """
  @spec estimate_cost(String.t(), map()) :: float()
  def estimate_cost(model, usage) when is_map(usage) do
    pricing = Map.get(@model_pricing_per_1k, model, %{input: 0.001, output: 0.002})
    prompt_tokens = Map.get(usage, "prompt_tokens", Map.get(usage, :prompt_tokens, 0))
    completion_tokens = Map.get(usage, "completion_tokens", Map.get(usage, :completion_tokens, 0))

    Float.round(
      prompt_tokens / 1000.0 * pricing.input + completion_tokens / 1000.0 * pricing.output,
      6
    )
  end

  defp handle_response(%{body: body}, config) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> handle_response(%{body: decoded}, config)
      {:error, _} -> {:error, "Failed to decode OpenRouter response body"}
    end
  end

  defp handle_response(%{body: body}, config) when is_map(body) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message} <- choice,
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
      usage = Map.get(body, "usage", %{})
      resolved_model = Map.get(body, "model", config.model)

      payload = %{
        content: content,
        model: resolved_model,
        finish_reason: Map.get(choice, "finish_reason", "stop"),
        tool_calls: message["tool_calls"],
        tool_calls_results: tool_calls_results
      }

      metadata = %{
        id: Map.get(body, "id", "or_msg"),
        created: Map.get(body, "created", System.system_time(:second)),
        usage: Map.put(usage, "estimated_cost_usd", estimate_cost(resolved_model, usage)),
        provider: Map.get(body, "provider")
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
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:ok, %{"text" => content}}
    end
  end

  defp execute_tool_calls(nil), do: {:ok, nil}
  defp execute_tool_calls([]), do: {:ok, []}

  defp execute_tool_calls(tool_calls) when is_list(tool_calls) do
    results =
      Enum.map(tool_calls, fn
        %{"function" => %{"name" => name, "arguments" => args}} when is_binary(args) ->
          case Jason.decode(args) do
            {:ok, decoded_args} -> {name, decoded_args}
            {:error, _} -> {name, args}
          end

        %{"function" => %{"name" => name, "arguments" => args}} ->
          {name, args}
      end)

    {:ok, results}
  end

  defp handle_error(error) do
    Logger.error("Error calling OpenRouter API: #{inspect(error)}")
    {:error, "Failed to call OpenRouter API"}
  end
end
