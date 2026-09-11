defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation that supports passing Beams, Prisms, and Lenses as tools.

  OpenRouter provides an OpenAI-compatible interface with custom headers for site
  attribution (`HTTP-Referer` and `X-OpenRouter-Title`). It acts as a unified
  gateway supporting hundreds of models from different providers (OpenAI,
  Anthropic, Meta, Google, etc.) through a single API.

  ## Differences from `Lux.LLM.OpenAI`

  - **`json_response` defaults to `false`**: OpenRouter is a multi-model gateway,
    and many models do not support `response_format`. Users should explicitly set
    `json_response: true` when using models that support structured output.

  - **Plain-text content handling**: Unlike the OpenAI provider, `parse_content/1`
    wraps non-JSON text responses in `%{"text" => content}` instead of returning
    an error. This is intentional since OpenRouter routes to models that
    frequently return plain-text responses.

  - **Site attribution headers**: Supports optional `HTTP-Referer` and
    `X-OpenRouter-Title` headers for app identification on OpenRouter leaderboards.
    Configure via `site_url`/`site_name` or `http_referer`/`openrouter_title` keys.

  ## Advanced OpenRouter Features

  - **Model Fallbacks & Provider Routing**: Callers can pass a fallback list of models
    via `models: ["openai/gpt-4o", "anthropic/claude-3.5-sonnet"]` or provider routing
    preferences via `provider: %{order: ["OpenAI", "Anthropic"], allow_fallbacks: true}`.
    Atoms `:cheapest`, `:default`, and `:smartest` are resolved from `config :lux, :open_router_models`.

  - **Retry & Rate-Limit Handling**: Automatically retries HTTP 429 (Too Many Requests)
    and 503 (No Available Provider) errors by reading the `Retry-After` response header,
    up to `max_retries` attempts (default: 3).

  - **HTTP 200 Error Envelope Decoding**: OpenRouter can return provider errors after
    HTTP 200 OK once generation starts. This module decodes `%{"error" => ...}` envelopes
    in status 200 responses into structured `{:error, {code, message, metadata}}` tuples.

  - **Usage Accounting & Cost Tracking**: Extracts exact cost in USD from the `usage`
    object (`cost`, `total_cost`, `cost_details`) and includes it in signal metadata.
    Provides `cost_summary/1` and `within_budget?/2` helpers for budget monitoring.
  """

  @behaviour Lux.LLM.Provider

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ModelConfig
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism
  alias Lux.Signal

  require Beam
  require Lens
  require Logger

  @default_endpoint "https://openrouter.ai/api/v1/chat/completions"

  @impl Lux.LLM.Provider
  def id, do: :openrouter

  @impl Lux.LLM.Provider
  def models do
    [
      %ModelConfig{
        id: "openai/gpt-4o",
        name: "OpenAI GPT-4o (via OpenRouter)",
        provider_id: :openrouter,
        cost_per_1k_prompt_tokens: 0.0025,
        cost_per_1k_completion_tokens: 0.010,
        capabilities: [:tools, :json_schema, :vision],
        context_window: 128_000
      },
      %ModelConfig{
        id: "anthropic/claude-3.5-sonnet",
        name: "Claude 3.5 Sonnet (via OpenRouter)",
        provider_id: :openrouter,
        cost_per_1k_prompt_tokens: 0.003,
        cost_per_1k_completion_tokens: 0.015,
        capabilities: [:tools, :json_schema, :vision],
        context_window: 200_000
      },
      %ModelConfig{
        id: "meta-llama/llama-3.1-70b-instruct",
        name: "Llama 3.1 70B Instruct (via OpenRouter)",
        provider_id: :openrouter,
        cost_per_1k_prompt_tokens: 0.00035,
        cost_per_1k_completion_tokens: 0.0004,
        capabilities: [:tools],
        context_window: 128_000
      }
    ]
  end

  defmodule Config do
    @moduledoc """
    Configuration module for OpenRouter.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t() | atom() | nil,
            models: [String.t() | atom()] | nil,
            provider: map() | nil,
            api_key: String.t() | nil,
            site_url: String.t() | nil,
            site_name: String.t() | nil,
            http_referer: String.t() | nil,
            openrouter_title: String.t() | nil,
            temperature: float(),
            frequency_penalty: float(),
            receive_timeout: integer(),
            max_retries: integer(),
            max_retry_delay: integer(),
            sleeper: (integer() -> any()) | nil,
            seed: integer() | nil,
            n: integer(),
            json_response: boolean(),
            json_schema: map() | atom() | nil,
            max_tokens: integer() | nil,
            tool_choice: map() | String.t() | atom() | nil,
            user: String.t() | nil,
            messages: [map()]
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: nil,
              models: nil,
              provider: nil,
              api_key: nil,
              site_url: nil,
              site_name: nil,
              http_referer: nil,
              openrouter_title: nil,
              temperature: 0.7,
              frequency_penalty: 0.0,
              receive_timeout: 60_000,
              max_retries: 3,
              max_retry_delay: 60_000,
              sleeper: nil,
              seed: nil,
              n: 1,
              # Defaults to false because OpenRouter is a multi-model gateway
              # and many models do not support response_format.
              json_response: false,
              json_schema: nil,
              max_tokens: nil,
              tool_choice: nil,
              user: nil,
              messages: []
  end

  @impl Lux.LLM.Provider
  def call(prompt, tools, config) do
    config = normalize_config(config)
    body = build_request_body(config, prompt, tools)
    headers = build_headers(config)

    req_options =
      [
        url: Lux.Config.resolve(config.endpoint || @default_endpoint),
        json: body,
        headers: headers,
        receive_timeout: config.receive_timeout
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    post_with_retry(req_options, config.max_retries, config)
    |> handle_retry_response(config)
  end

  defp normalize_config(config) do
    opts_map =
      case config do
        %_{} -> Map.from_struct(config)
        %{} -> config
        list when is_list(list) -> Enum.into(list, %{})
        _ -> %{}
      end

    default_model = resolve_model_name(:default) || "openai/gpt-4o-mini"

    default_api_key =
      case Application.get_env(:lux, :api_keys) do
        keys when is_list(keys) -> keys[:openrouter]
        _ -> nil
      end

    struct(
      Config,
      Map.merge(
        %{
          model: default_model,
          api_key: default_api_key
        },
        opts_map
      )
    )
  end

  defp build_request_body(config, prompt, tools) do
    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)
    resolved_model = resolve_model_name(config.model)

    resolved_models =
      if is_list(config.models), do: Enum.map(config.models, &resolve_model_name/1), else: nil

    %{
      messages: messages,
      temperature: config.temperature,
      frequency_penalty: config.frequency_penalty
    }
    |> maybe_add_model(resolved_model, resolved_models)
    |> maybe_add_provider(config.provider)
    |> maybe_add_max_tokens(config.max_tokens)
    |> maybe_add_tools(tools_config, config.tool_choice)
    |> maybe_add_response_format(config)
    |> maybe_add_user(config.user)
    |> maybe_add_n(config.n)
  end

  defp handle_retry_response({:ok, %{status: 200} = response}, config) do
    handle_response(response, config)
  end

  defp handle_retry_response({:ok, %{status: 401}}, _config) do
    {:error, :invalid_api_key}
  end

  defp handle_retry_response({:ok, %{status: status, body: body, headers: resp_headers}}, _config)
       when status in [429, 503] do
    {:error, {_, msg, meta}} = decode_error(body)
    retry_after = get_header_value(resp_headers, "retry-after")
    ratelimit_remaining = get_header_value(resp_headers, "x-ratelimit-remaining")

    meta =
      meta
      |> Map.put(:retry_after, retry_after)
      |> Map.put(:ratelimit_remaining, ratelimit_remaining)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    if meta == %{} do
      {:error, {status, msg}}
    else
      {:error, {status, msg, meta}}
    end
  end

  defp handle_retry_response({:ok, %{status: status, body: body}}, _config) do
    {:error, {code, msg, meta}} = decode_error(body)
    st = status || code

    if is_map(meta) and map_size(meta) > 0 do
      {:error, {st, msg, meta}}
    else
      {:error, {st, msg}}
    end
  end

  defp handle_retry_response({:error, error}, _config) do
    handle_error(error)
  end

  defp build_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, [], _tool_choice), do: body

  defp maybe_add_tools(body, tools, tool_choice) do
    body
    |> Map.put(:tools, tools)
    |> Map.put(:tool_choice, format_tool_choice(tool_choice))
  end

  defp format_tool_choice(:none), do: "none"
  defp format_tool_choice(:auto), do: "auto"

  defp format_tool_choice(name) when is_binary(name) do
    %{"type" => "function", "function" => %{"name" => String.replace(name, ".", "_")}}
  end

  defp format_tool_choice(choice) when is_map(choice), do: choice
  defp format_tool_choice(_), do: "auto"

  defp maybe_add_max_tokens(body, nil), do: body
  defp maybe_add_max_tokens(body, max_tokens), do: Map.put(body, :max_tokens, max_tokens)

  defp maybe_add_user(body, nil), do: body
  defp maybe_add_user(body, user), do: Map.put(body, :user, user)

  defp maybe_add_n(body, nil), do: body
  defp maybe_add_n(body, 1), do: body
  defp maybe_add_n(body, n), do: Map.put(body, :n, n)

  defp maybe_add_response_format(body, %Config{json_response: false}), do: body

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_map(schema) and map_size(schema) > 0 do
    Map.put(body, :response_format, %{
      type: "json_schema",
      json_schema: schema
    })
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_atom(schema) and not is_nil(schema) do
    Map.put(body, :response_format, %{
      type: "json_schema",
      json_schema: %{name: schema.name(), schema: schema.schema()}
    })
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: nil}) do
    Map.put(
      %{
        body
        | messages:
            Enum.map(body.messages, fn
              %{role: "user", content: content} = msg ->
                %{msg | content: content <> "\n Reply in json format"}

              msg ->
                msg
            end)
      },
      :response_format,
      %{type: "json_object"}
    )
  end

  defp maybe_add_response_format(body, _), do: body

  defp build_headers(config) do
    resolved_api_key = Lux.Config.resolve(config.api_key)

    [
      {"Authorization", "Bearer #{resolved_api_key}"},
      {"Content-Type", "application/json"}
    ]
    |> maybe_append_header("HTTP-Referer", resolve_first_present([config.http_referer, config.site_url]))
    |> maybe_append_header("X-OpenRouter-Title", resolve_first_present([config.openrouter_title, config.site_name]))
  end

  defp resolve_first_present(candidates) do
    Enum.find_value(candidates, fn
      val when not is_nil(val) and val != "" -> Lux.Config.resolve(val)
      _ -> nil
    end)
  end

  defp maybe_append_header(headers, header_name, val) when is_binary(val) and val != "" do
    headers ++ [{header_name, val}]
  end

  defp maybe_append_header(headers, _header_name, _val), do: headers

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
        # OpenRouter function names must be [a-zA-Z0-9_-]
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
        # OpenRouter function names must be [a-zA-Z0-9_-]
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_function(%Lens{module_name: name, description: description, schema: schema, params: params}) do
    parameters =
      cond do
        is_map(schema) and map_size(schema) > 0 -> schema
        is_map(params) and map_size(params) > 0 -> params
        true -> %{}
      end

    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: parameters
      }
    }
  end

  defp handle_response(%{body: body}, config) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> handle_response(%{body: decoded}, config)
      {:error, _} -> {:error, "Failed to decode response body: #{inspect(body)}"}
    end
  end

  defp handle_response(%{body: %{"error" => _} = body}, _config) do
    decode_error(body)
  end

  defp handle_response(%{body: body}, _config) when is_map(body) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message} <- choice do
      finish_reason = Map.get(choice, "finish_reason") || "stop"

      with {:ok, content} <- parse_content(message["content"]),
           {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
        payload = %{
          content: content,
          model: body["model"],
          finish_reason: finish_reason,
          tool_calls: message["tool_calls"],
          tool_calls_results: tool_calls_results
        }

        usage = normalize_usage(body["usage"])

        metadata = %{
          id: body["id"],
          created: body["created"],
          usage: usage,
          system_fingerprint: body["system_fingerprint"]
        }

        %{
          schema_id: ResponseSignal,
          payload: payload,
          metadata: metadata
        }
        |> Lux.Signal.new()
        |> ResponseSignal.validate()
      end
    else
      _ -> {:error, "Invalid response payload from OpenRouter"}
    end
  end

  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} when is_map(structured_output) ->
        {:ok, structured_output}

      {:error, _} ->
        {:ok, %{"text" => content}}

      {:ok, other} ->
        {:ok, %{"text" => inspect(other)}}
    end
  end

  def parse_content(nil), do: {:ok, nil}
  def parse_content(other), do: {:ok, other}

  def execute_tool_calls(tool_calls) when is_list(tool_calls) do
    results = Enum.map(tool_calls, &execute_tool_call/1)

    if Enum.all?(results, fn
         {:ok, _} -> true
         {:ok, _, _} -> true
         _ -> false
       end) do
      unwrapped =
        Enum.map(results, fn
          {:ok, res, _log} -> res
          {:ok, res} -> res
        end)

      {:ok, unwrapped}
    else
      error = Enum.find(results, &match?({:error, _}, &1)) || {:error, "Tool call execution failed"}
      error
    end
  end

  def execute_tool_calls(nil), do: {:ok, nil}

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) when is_binary(args) do
    case Jason.decode(args) do
      {:ok, decoded_args} ->
        try do
          execute_tool(tool_name, decoded_args, nil)
        rescue
          e -> {:error, "Error executing tool #{tool_name}: #{inspect(e)}"}
        end

      {:error, error} ->
        {:error, "Failed to decode arguments for tool #{tool_name}: #{inspect(error)}"}
    end
  end

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) when is_map(args) do
    try do
      execute_tool(tool_name, args, nil)
    rescue
      e -> {:error, "Error executing tool #{tool_name}: #{inspect(e)}"}
    end
  end

  def execute_tool_call(%{"function" => %{"name" => tool_name}}) do
    {:error, "Missing arguments for tool #{tool_name}"}
  end

  def execute_tool_call(other) do
    {:error, "Invalid tool call format: #{inspect(other)}"}
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
         "Failed to load tool module #{tool_name}: It doesn't seems to be implemented or reacheable"}

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

  defp handle_error(error) do
    Logger.error("OpenRouter API error: #{inspect(error)}")
    {:error, "OpenRouter API error: #{inspect(error)}"}
  end

  # --- Helpers for Routing, Retries, Cost Accounting, and Error Decoding ---

  defp resolve_model_name(atom) when is_atom(atom) and not is_nil(atom) do
    case Application.get_env(:lux, :open_router_models) do
      models when is_list(models) -> models[atom] || to_string(atom)
      _ -> to_string(atom)
    end
  end

  defp resolve_model_name(str) when is_binary(str), do: Lux.Config.resolve(str)
  defp resolve_model_name(nil), do: nil
  defp resolve_model_name(other), do: other

  defp maybe_add_model(body, nil, nil), do: Map.put(body, :model, "openai/gpt-4o-mini")
  defp maybe_add_model(body, model, nil), do: Map.put(body, :model, model)
  defp maybe_add_model(body, nil, models) when is_list(models), do: Map.put(body, :models, models)

  defp maybe_add_model(body, model, models) when is_list(models) do
    body
    |> Map.put(:model, model)
    |> Map.put(:models, models)
  end

  defp maybe_add_provider(body, nil), do: body
  defp maybe_add_provider(body, provider) when is_map(provider), do: Map.put(body, :provider, provider)
  defp maybe_add_provider(body, _), do: body

  defp post_with_retry(req_options, attempts_left, config) do
    case Req.new(req_options) |> Req.post() do
      {:ok, %{status: status, headers: headers} = response}
      when status in [429, 503] and attempts_left > 1 ->
        delay = parse_retry_after(headers)
        max_delay = Map.get(config, :max_retry_delay, 60_000) || 60_000

        if delay > max_delay do
          {:ok, response}
        else
          sleeper = Map.get(config, :sleeper) || (&Process.sleep/1)
          sleeper.(delay)
          post_with_retry(req_options, attempts_left - 1, config)
        end

      other ->
        other
    end
  end

  defp parse_retry_after(headers) do
    case get_header_value(headers, "retry-after") do
      nil ->
        500

      val ->
        case Integer.parse(to_string(val)) do
          {sec, _} -> max(sec * 1000, 0)
          :error -> 500
        end
    end
  end

  defp get_header_value(headers, name) when is_list(headers) or is_map(headers) do
    Enum.find_value(headers, fn
      {k, v} when is_binary(k) ->
        if String.downcase(k) == name, do: extract_header_val(v)

      _ ->
        nil
    end)
  end

  defp get_header_value(_, _), do: nil

  defp extract_header_val(v) when is_list(v), do: List.first(v)
  defp extract_header_val(v), do: v

  defp normalize_usage(%{} = u) do
    cost =
      case {u["cost"], u["total_cost"]} do
        {c, _} when is_number(c) -> c * 1.0
        {_, c} when is_number(c) -> c * 1.0
        _ -> 0.0
      end

    %{
      "prompt_tokens" => u["prompt_tokens"] || 0,
      "completion_tokens" => u["completion_tokens"] || 0,
      "total_tokens" => u["total_tokens"] || 0,
      "cost" => cost,
      "total_cost" => cost,
      "cost_details" => u["cost_details"] || %{}
    }
  end

  defp normalize_usage(_) do
    %{
      "prompt_tokens" => 0,
      "completion_tokens" => 0,
      "total_tokens" => 0,
      "cost" => 0.0,
      "total_cost" => 0.0,
      "cost_details" => %{}
    }
  end

  @doc """
  Decodes OpenRouter error envelopes from either HTTP 200 or non-200 responses
  into a structured `{:error, {code, message, metadata}}` tuple.
  """
  def decode_error(%{"error" => %{"code" => code, "message" => message} = err_map}) do
    metadata = Map.get(err_map, "metadata", %{})
    {:error, {code, message, metadata}}
  end

  def decode_error(%{"error" => %{"message" => message} = err_map}) do
    code = Map.get(err_map, "code", 500)
    metadata = Map.get(err_map, "metadata", %{})
    {:error, {code, message, metadata}}
  end

  def decode_error(%{"error" => message}) when is_binary(message) do
    {:error, {500, message, %{}}}
  end

  def decode_error(other) when is_binary(other) do
    case Jason.decode(other) do
      {:ok, decoded} -> decode_error(decoded)
      _ -> {:error, {500, other, %{}}}
    end
  end

  def decode_error(other) do
    {:error, {500, inspect(other), %{}}}
  end

  @doc """
  Aggregates cost and token usage statistics across a single `ResponseSignal`
  or a list of `ResponseSignal` structs (or raw usage maps).
  """
  def cost_summary(signals_or_usages) when is_list(signals_or_usages) do
    Enum.reduce(
      signals_or_usages,
      %{
        total_cost: 0.0,
        total_tokens: 0,
        prompt_tokens: 0,
        completion_tokens: 0,
        by_model: %{}
      },
      fn item, acc ->
        {usage, model} = extract_usage_and_model(item)
        cost = Map.get(usage, "cost", 0.0)
        p_tokens = Map.get(usage, "prompt_tokens", 0)
        c_tokens = Map.get(usage, "completion_tokens", 0)
        t_tokens = Map.get(usage, "total_tokens", p_tokens + c_tokens)

        model_key = model || "unknown"
        current_model_stats = Map.get(acc.by_model, model_key, %{cost: 0.0, calls: 0, tokens: 0})
        updated_model_stats = %{
          cost: current_model_stats.cost + cost,
          calls: current_model_stats.calls + 1,
          tokens: current_model_stats.tokens + t_tokens
        }

        %{
          total_cost: acc.total_cost + cost,
          total_tokens: acc.total_tokens + t_tokens,
          prompt_tokens: acc.prompt_tokens + p_tokens,
          completion_tokens: acc.completion_tokens + c_tokens,
          by_model: Map.put(acc.by_model, model_key, updated_model_stats)
        }
      end
    )
  end

  def cost_summary(signal_or_usage), do: cost_summary([signal_or_usage])

  defp extract_usage_and_model(%Signal{metadata: %{usage: usage}, payload: %{model: model}}),
    do: {usage, model}

  defp extract_usage_and_model(%Signal{metadata: %{usage: usage}}), do: {usage, "unknown"}
  defp extract_usage_and_model(%{"cost" => _} = usage), do: {usage, "unknown"}
  defp extract_usage_and_model(_), do: {%{}, "unknown"}

  @doc """
  Checks if a single `ResponseSignal`, usage map, or accumulated cost float
  is within a specified `max_budget_usd`.
  """
  def within_budget?(cost_float, max_budget_usd) when is_number(cost_float) and is_number(max_budget_usd) do
    cost_float <= max_budget_usd
  end

  def within_budget?(%{} = signal_or_usage, max_budget_usd) when is_number(max_budget_usd) do
    summary = cost_summary(signal_or_usage)
    summary.total_cost <= max_budget_usd
  end
end
