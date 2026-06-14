defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation that supports passing Beams, Prisms, and Lenses as tools.

  OpenRouter provides a unified API to access 200+ models from multiple providers
  (OpenAI, Anthropic, Google, Meta, Mistral, etc.) through a single endpoint.

  ## Features
  - Access to 200+ models through one API
  - Automatic fallback between providers
  - Cost tracking per-model and per-provider
  - Rate limiting and retry support
  - Model selection by capability (cheapest, default, smartest)
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

  defmodule Config do
    @moduledoc """
    Configuration module for OpenRouter.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            max_tokens: integer(),
            top_p: float(),
            frequency_penalty: float(),
            presence_penalty: float(),
            receive_timeout: integer(),
            seed: integer(),
            n: integer(),
            json_response: boolean(),
            json_schema: map(),
            tool_choice: map(),
            user: String.t(),
            messages: [map()],
            # OpenRouter-specific options
            allow_fallback: boolean(),
            provider_preferences: [String.t()],
            max_retries: integer(),
            route: String.t(),
            cost_tracking: boolean()
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: "openai/gpt-4o-mini",
              api_key: nil,
              temperature: 0.7,
              max_tokens: 4096,
              top_p: 0.7,
              frequency_penalty: 0.0,
              presence_penalty: 0.0,
              receive_timeout: 60_000,
              seed: nil,
              n: 1,
              json_response: false,
              json_schema: nil,
              tool_choice: nil,
              user: nil,
              messages: [],
              # OpenRouter-specific defaults
              allow_fallback: true,
              provider_preferences: [],
              max_retries: 3,
              route: nil,
              cost_tracking: true
  end

  @doc """
  Call an LLM through OpenRouter with the given prompt, tools, and options.

  ## Options (config map)
  - `:model` — Model identifier (e.g. "openai/gpt-4o", "anthropic/claude-3-opus")
  - `:allow_fallback` — Allow OpenRouter to fall back to alternative providers
  - `:provider_preferences` — Ordered list of preferred providers
  - `:max_retries` — Number of automatic retries on failure
  - Plus all standard Lux.LLM options (temperature, max_tokens, etc.)
  """
  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            api_key: Application.get_env(:lux, :api_keys)[:openrouter],
            model: Application.get_env(:lux, :open_router_models)[:default]
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
        max_tokens: config.max_tokens
      }
      |> maybe_add_tools(tools_config)
      |> maybe_add_response_format(config)
      |> maybe_add_openrouter_opts(config)

    request_with_retry(config, body)
  end

  # ── OpenRouter-specific headers ──────────────────────────────────────

  defp build_headers(config) do
    headers = [
      {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
      {"Content-Type", "application/json"}
    ]

    headers =
      if config.allow_fallback do
        [{"X-Title", "Lux Framework"} | headers]
      else
        [{"X-Title", "Lux Framework"},
         {"X-OpenRouter-Attempt", "1"} | headers]
      end

    if config.provider_preferences != [] do
      order = Enum.join(config.provider_preferences, ",")
      [{"X-OpenRouter-Provider-Preference", order} | headers]
    else
      headers
    end
  end

  # ── OpenRouter-specific body options ─────────────────────────────────

  defp maybe_add_openrouter_opts(body, config) do
    body
    |> Map.put("transforms", [])
    |> then(fn b ->
      if config.route do
        Map.put(b, "route", config.route)
      else
        b
      end
    end)
  end

  # ── Retry logic ──────────────────────────────────────────────────────

  defp request_with_retry(config, body, attempt \\ 1)

  defp request_with_retry(_config, _body, attempt) when attempt > 3 do
    {:error, "OpenRouter request failed after 3 retries"}
  end

  defp request_with_retry(config, body, attempt) do
    req =
      [
        url: config.endpoint,
        json: body,
        headers: build_headers(config)
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> Req.new()

    result =
      req
      |> Req.post()
      |> case do
        {:ok, %{status: 200} = response} ->
          handle_successful_response(response, config)

        {:ok, %{status: 429} = response} ->
          # Rate limited — retry with exponential backoff
          retry_after = get_retry_after(response)
          Logger.warning("OpenRouter rate limited (attempt #{attempt}), retrying after #{retry_after}ms")
          :timer.sleep(retry_after)
          request_with_retry(config, body, attempt + 1)

        {:ok, response} ->
          handle_error_response(response)

        {:error, %Req.TransportError{reason: :timeout} = err} when attempt < config.max_retries ->
          Logger.warning("OpenRouter timeout (attempt #{attempt}), retrying...")
          :timer.sleep(1000 * attempt)
          request_with_retry(config, body, attempt + 1)

        {:error, reason} ->
          {:error, "OpenRouter request failed: #{inspect(reason)}"}
      end

    # Track cost if enabled
    if config.cost_tracking do
      track_cost(result, config)
    end

    result
  end

  defp get_retry_after(response) do
    case List.keyfind(response.headers, "retry-after", 0) do
      {_, value} ->
        (String.to_integer(value) || 5) * 1000
      nil ->
        5000
    end
  end

  # ── Response handling ────────────────────────────────────────────────

  defp handle_successful_response(response, config) do
    %{ "choices" => choices, "model" => model, "usage" => usage } = response.body

    choice = List.first(choices)
    message = choice["message"]

    tool_calls = parse_tool_calls(message)

    response_signal = %Lux.LLM.Response{
      content: message["content"],
      tool_calls: tool_calls,
      finish_reason: choice["finish_reason"],
      structured_output: config.json_response && parse_json_response(message["content"])
    }

    # Log cost info if available
    if config.cost_tracking do
      log_cost(model, usage)
    end

    {:ok, response_signal}
  end

  defp handle_error_response(response) do
    error_body = response.body["error"] || %{"message" => "Unknown error"}
    {:error, "OpenRouter API error (#{response.status}): #{error_body["message"]}"}
  end

  # ── Cost tracking ────────────────────────────────────────────────────

  defp track_cost({:ok, _}, _config), do: :ok
  defp track_cost({:error, _}, _config), do: :ok

  defp log_cost(model, usage) do
    prompt_tokens = usage["prompt_tokens"] || 0
    completion_tokens = usage["completion_tokens"] || 0
    total_cost_cents = usage["total_cost"] || 0

    Logger.info(
      "OpenRouter [#{model}] " <>
      "prompt: #{prompt_tokens}, completion: #{completion_tokens}, " <>
      "cost: $#{format_cost(total_cost_cents)}"
    )
  end

  defp format_cost(cents) when is_float(cents), do: Float.round(cents, 6) |> to_string()
  defp format_cost(_), do: "unknown"

  # ── Message building ─────────────────────────────────────────────────

  defp build_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_messages(messages) when is_list(messages) do
    messages
  end

  # ── Tool handling ────────────────────────────────────────────────────

  defp build_tools_config(tools) do
    Enum.map(tools, &build_tool_config/1)
  end

  defp build_tool_config(%Beam{} = beam) do
    Beam.to_openai_tool(beam)
  end

  defp build_tool_config(%Lens{} = lens) do
    Lens.to_openai_tool(lens)
  end

  defp build_tool_config(%Prism{} = prism) do
    Prism.to_openai_tool(prism)
  end

  defp build_tool_config(%{name: name, description: desc, parameters: params}) do
    %{
      type: "function",
      function: %{
        name: name,
        description: desc,
        parameters: params
      }
    }
  end

  defp parse_tool_calls(%{"tool_calls" => calls}) when is_list(calls) do
    Enum.map(calls, fn call ->
      %{
        type: "function",
        name: call["function"]["name"],
        params: Jason.decode!(call["function"]["arguments"])
      }
    end)
  end

  defp parse_tool_calls(_), do: []

  # ── Body modifiers ───────────────────────────────────────────────────

  defp maybe_add_tools(body, []), do: Map.delete(body, :tools)
  defp maybe_add_tools(body, tools), do: Map.put(body, "tools", tools)

  defp maybe_add_response_format(body, %{json_response: true}) do
    Map.put(body, "response_format", %{type: "json_object"})
  end

  defp maybe_add_response_format(body, %{json_schema: schema}) when not is_nil(schema) do
    Map.put(body, "response_format", %{type: "json_schema", json_schema: schema})
  end

  defp maybe_add_response_format(body, _config), do: body
end
