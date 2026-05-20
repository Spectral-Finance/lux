defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter client for Lux LLM integrations.

  OpenRouter exposes an OpenAI-compatible chat completions API with routing
  options for provider selection, model fallbacks, provider load balancing,
  sorting, quantization and cache-control metadata.

  ## Configuration

  Set `OPENROUTER_API_KEY` in the environment, or pass `:api_key` per request.

      Lux.LLM.OpenRouter.chat([
        %{role: "user", content: "Write a haiku about Elixir"}
      ], model: "openai/gpt-4o-mini")

  ## Routing options

      Lux.LLM.OpenRouter.chat(messages,
        model: "anthropic/claude-3.5-sonnet",
        fallbacks: ["openai/gpt-4o", "google/gemini-pro"],
        provider: %{
          sort: "price",
          allow_fallbacks: true,
          quantizations: ["bf16", "fp8"]
        },
        transforms: ["middle-out"],
        cache_control: %{type: "ephemeral"}
      )

  The client retries transient transport, rate-limit and 5xx errors with
  exponential backoff, and annotates successful responses with estimated cost
  metadata under the `"lux"` key.
  """

  defmodule Error do
    @moduledoc "OpenRouter error returned by `Lux.LLM.OpenRouter`."

    defexception [:type, :status, :message, :body, retryable?: false]
  end

  @default_base_url "https://openrouter.ai/api/v1"
  @default_model "openai/gpt-4o-mini"
  @default_timeout 60_000
  @default_retries 2
  @default_retry_delay 250

  @known_models %{
    "anthropic/claude-3.5-sonnet" => %{prompt: 3.0, completion: 15.0},
    "openai/gpt-4o" => %{prompt: 2.5, completion: 10.0},
    "openai/gpt-4o-mini" => %{prompt: 0.15, completion: 0.6},
    "google/gemini-pro" => %{prompt: 0.5, completion: 1.5},
    "meta-llama/llama-3-70b-instruct" => %{prompt: 0.59, completion: 0.79},
    "mistralai/mistral-7b-instruct" => %{prompt: 0.06, completion: 0.06}
  }

  @optional_body_keys [
    :temperature,
    :max_tokens,
    :top_p,
    :top_k,
    :frequency_penalty,
    :presence_penalty,
    :repetition_penalty,
    :seed,
    :stop,
    :tools,
    :tool_choice,
    :stream,
    :response_format,
    :transforms,
    :models,
    :route,
    :provider,
    :reasoning,
    :usage,
    :cache_control,
    :prediction,
    :plugins
  ]

  @doc "Returns model identifiers with bundled cost metadata."
  @spec models() :: map()
  def models, do: @known_models

  @doc "Returns bundled cost metadata for a model, if known."
  @spec model_info(String.t()) :: map() | nil
  def model_info(model), do: Map.get(@known_models, model)

  @doc "OpenAI-compatible chat completion request."
  @spec chat(list(), keyword() | map()) :: {:ok, map()} | {:error, Error.t()}
  def chat(messages, opts \\ []), do: chat_completion(messages, opts)

  @doc "Alias for `chat/2` used by provider-style integrations."
  @spec completion(list(), keyword() | map()) :: {:ok, map()} | {:error, Error.t()}
  def completion(messages, opts \\ []), do: chat(messages, opts)

  @doc "Alias for `chat/2` used by provider-style integrations."
  @spec generate(list(), keyword() | map()) :: {:ok, map()} | {:error, Error.t()}
  def generate(messages, opts \\ []), do: chat(messages, opts)

  @doc "Convenience helper for a single user prompt."
  @spec complete(String.t(), keyword() | map()) :: {:ok, map()} | {:error, Error.t()}
  def complete(prompt, opts \\ []) when is_binary(prompt) do
    chat([%{role: "user", content: prompt}], opts)
  end

  @doc "Bang variant of `chat/2`."
  @spec chat!(list(), keyword() | map()) :: map()
  def chat!(messages, opts \\ []) do
    case chat(messages, opts) do
      {:ok, response} -> response
      {:error, error} -> raise error
    end
  end

  @doc "Builds the JSON request body for a model and option set."
  @spec build_request_body(String.t(), list(), keyword() | map()) :: map()
  def build_request_body(model, messages, opts \\ []) do
    opts = normalize_opts(opts)

    %{"model" => model, "messages" => Enum.map(messages, &stringify_keys/1)}
    |> put_optional_body_fields(opts)
    |> maybe_put_json_response(opts)
  end

  @doc "Estimates request cost from OpenRouter/OpenAI usage data."
  @spec calculate_cost(map() | nil, String.t()) :: map()
  def calculate_cost(nil, model), do: calculate_cost(%{}, model)

  def calculate_cost(usage, model) when is_map(usage) do
    cond do
      is_number(usage["cost"]) ->
        %{
          "total_cost" => usage["cost"],
          "currency" => "USD",
          "source" => "openrouter"
        }

      is_map(usage["cost"]) ->
        Map.merge(%{"currency" => "USD", "source" => "openrouter"}, usage["cost"])

      true ->
        pricing = Map.get(@known_models, model, %{prompt: 0.0, completion: 0.0})
        prompt_tokens = token_count(usage, ["prompt_tokens", "input_tokens"])
        completion_tokens = token_count(usage, ["completion_tokens", "output_tokens"])
        prompt_cost = prompt_tokens * pricing.prompt / 1_000_000
        completion_cost = completion_tokens * pricing.completion / 1_000_000

        %{
          "prompt_tokens_cost" => prompt_cost,
          "completion_tokens_cost" => completion_cost,
          "total_cost" => prompt_cost + completion_cost,
          "currency" => "USD",
          "source" => if(Map.has_key?(@known_models, model), do: "estimated", else: "unknown")
        }
    end
  end

  @doc "OpenAI-compatible chat completion request with fallback models."
  @spec chat_completion(list(), keyword() | map()) :: {:ok, map()} | {:error, Error.t()}
  def chat_completion(messages, opts \\ []) when is_list(messages) do
    opts = normalize_opts(opts)

    with {:ok, api_key} <- api_key(opts) do
      models = selected_models(opts)

      models
      |> Enum.reduce_while(nil, fn model, last_error ->
        request_opts = Map.put(opts, :model, model)

        case request_model(model, messages, api_key, request_opts) do
          {:ok, response} ->
            {:halt, {:ok, annotate_response(response, model, models)}}

          {:error, %Error{retryable?: true} = error} ->
            {:cont, error}

          {:error, error} ->
            if model == List.last(models), do: {:halt, {:error, error}}, else: {:cont, error}
        end
      end)
      |> case do
        nil -> {:error, error(:invalid_request, "no OpenRouter model configured")}
        {:ok, _response} = ok -> ok
        %Error{} = last_error -> {:error, last_error}
        {:error, _error} = error -> error
      end
    end
  end

  defp request_model(model, messages, api_key, opts) do
    body = build_request_body(model, messages, opts)
    retries = Map.get(opts, :retries, @default_retries)
    retry_delay = Map.get(opts, :retry_delay, @default_retry_delay)

    with_retries(fn -> do_request(body, api_key, opts) end, retries, retry_delay)
  end

  defp do_request(body, api_key, opts) do
    encoded_body = Jason.encode!(body)
    http_client = Map.get(opts, :http_client, &:httpc.request/4)
    timeout = Map.get(opts, :timeout, @default_timeout)

    request = {
      endpoint(opts),
      headers(api_key, opts),
      'application/json',
      encoded_body
    }

    http_options = [timeout: timeout, connect_timeout: timeout]
    options = [body_format: :binary]

    case http_client.(:post, request, http_options, options) do
      {:ok, {{_, status, _}, response_headers, response_body}} ->
        decode_response(status, response_headers, response_body)

      {:error, reason} ->
        {:error, error(:transport, "OpenRouter request failed: #{inspect(reason)}", nil, nil, true)}
    end
  end

  defp with_retries(fun, retries, delay) do
    case fun.() do
      {:error, %Error{retryable?: true}} = error when retries > 0 ->
        Process.sleep(delay)
        with_retries(fun, retries - 1, delay * 2)

      result ->
        result
    end
  end

  defp decode_response(status, _headers, response_body) when status in 200..299 do
    case Jason.decode(response_body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:error, error(:decode, "invalid OpenRouter JSON response: #{inspect(reason)}")}
    end
  end

  defp decode_response(status, _headers, response_body) do
    decoded = decode_json(response_body)
    message = error_message(decoded, response_body)
    {:error, error(:api, message, status, decoded, retryable_status?(status))}
  end

  defp decode_json(body) do
    case Jason.decode(body || "") do
      {:ok, decoded} -> decoded
      {:error, _reason} -> body
    end
  end

  defp error_message(%{"error" => %{"message" => message}}, _body), do: message
  defp error_message(%{"message" => message}, _body), do: message
  defp error_message(_decoded, body), do: "OpenRouter request failed: #{inspect(body)}"

  defp retryable_status?(status), do: status == 429 or status in 500..599

  defp annotate_response(response, requested_model, attempted_models) do
    model = response["model"] || requested_model
    usage = response["usage"] || %{}

    metadata = %{
      "provider" => "openrouter",
      "requested_model" => requested_model,
      "model" => model,
      "attempted_models" => attempted_models,
      "cost" => calculate_cost(usage, model)
    }

    Map.put(response, "lux", metadata)
  end

  defp api_key(opts) do
    case Map.get(opts, :api_key) || System.get_env("OPENROUTER_API_KEY") do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, error(:authentication, "missing OpenRouter API key")}
    end
  end

  defp endpoint(opts) do
    base_url = Map.get(opts, :base_url, @default_base_url) |> String.trim_trailing("/")
    String.to_charlist(base_url <> "/chat/completions")
  end

  defp headers(api_key, opts) do
    base_headers = [
      {'authorization', String.to_charlist("Bearer " <> api_key)},
      {'accept', 'application/json'}
    ]

    base_headers
    |> maybe_header('http-referer', Map.get(opts, :http_referer) || Map.get(opts, :referer))
    |> maybe_header('x-title', Map.get(opts, :app_name) || Map.get(opts, :title))
  end

  defp maybe_header(headers, _name, nil), do: headers
  defp maybe_header(headers, name, value), do: [{name, String.to_charlist(to_string(value))} | headers]

  defp selected_models(opts) do
    primary = Map.get(opts, :model) || Map.get(opts, :model_id) || @default_model
    fallbacks = Map.get(opts, :fallbacks) || Map.get(opts, :fallback_models) || []

    opts
    |> Map.get(:models, List.wrap(primary) ++ List.wrap(fallbacks))
    |> List.wrap()
    |> Enum.map(&normalize_model/1)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp normalize_model(:auto), do: "openrouter/auto"
  defp normalize_model(model), do: to_string(model)

  defp put_optional_body_fields(body, opts) do
    Enum.reduce(@optional_body_keys, body, fn key, acc ->
      case Map.fetch(opts, key) do
        {:ok, nil} -> acc
        {:ok, value} -> Map.put(acc, Atom.to_string(key), stringify_keys(value))
        :error -> acc
      end
    end)
  end

  defp maybe_put_json_response(body, opts) do
    cond do
      Map.get(opts, :json_response) == true ->
        Map.put(body, "response_format", %{"type" => "json_object"})

      schema = Map.get(opts, :json_schema) ->
        Map.put(body, "response_format", %{
          "type" => "json_schema",
          "json_schema" => stringify_keys(schema)
        })

      true ->
        body
    end
  end

  defp stringify_keys(value) when is_map(value) do
    Map.new(value, fn {key, inner_value} -> {string_key(key), stringify_keys(inner_value)} end)
  end

  defp stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)
  defp stringify_keys(value), do: value

  defp string_key(key) when is_atom(key), do: Atom.to_string(key)
  defp string_key(key), do: to_string(key)

  defp normalize_opts(opts) when is_map(opts), do: Map.new(opts)
  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)

  defp token_count(usage, keys) do
    keys
    |> Enum.find_value(0, fn key -> usage[key] end)
    |> case do
      value when is_integer(value) -> value
      value when is_float(value) -> value
      _ -> 0
    end
  end

  defp error(type, message, status \\ nil, body \\ nil, retryable? \\ false) do
    %Error{type: type, status: status, message: message, body: body, retryable?: retryable?}
  end
end
