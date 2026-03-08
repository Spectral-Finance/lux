defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation providing access to a wide range of models through
  a single unified API.

  OpenRouter routes requests to the best available provider for each model,
  supporting 200+ models from OpenAI, Anthropic, Google, Meta, Mistral, and more.

  ## Features

  - Access to 200+ models through a unified API
  - Automatic provider selection and fallback
  - Cost tracking and optimization
  - Rate limiting with retry support
  - Provider preferences and routing controls
  - OpenAI-compatible API format

  ## Configuration

      config :lux, :api_keys, openrouter: "sk-or-v1-..."
      config :lux, :open_router_models, default: "anthropic/claude-sonnet-4-20250514"

  ## Usage

      Lux.LLM.OpenRouter.call("Hello", [], %{
        model: "anthropic/claude-sonnet-4-20250514",
        api_key: "sk-or-v1-..."
      })

  ## Provider Preferences

  You can control routing with provider preferences:

      %{
        provider: %{
          order: ["Anthropic", "OpenAI"],
          allow_fallbacks: true,
          require_parameters: true
        }
      }

  ## Cost Tracking

  Response metadata includes cost information when available:

      %{
        usage: %{
          "prompt_tokens" => 10,
          "completion_tokens" => 20,
          "total_tokens" => 30
        },
        cost: %{
          "prompt" => 0.00003,
          "completion" => 0.00006,
          "total" => 0.00009
        }
      }
  """

  @behaviour Lux.LLM

  alias Lux.LLM.OpenAI
  alias Lux.LLM.ResponseSignal
  require Logger

  @endpoint "https://openrouter.ai/api/v1/chat/completions"
  @models_endpoint "https://openrouter.ai/api/v1/models"

  @max_retries 3
  @base_retry_delay 1_000

  defmodule Config do
    @moduledoc """
    Configuration module for OpenRouter.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            frequency_penalty: float(),
            receive_timeout: integer(),
            seed: integer(),
            n: integer(),
            json_response: boolean(),
            json_schema: map(),
            max_tokens: integer(),
            tool_choice: map(),
            user: String.t(),
            messages: [map()],
            site_url: String.t() | nil,
            site_name: String.t() | nil,
            provider: map() | nil,
            transforms: [String.t()] | nil,
            route: String.t() | nil
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: "openai/gpt-4",
              api_key: nil,
              temperature: 0.7,
              frequency_penalty: 0.0,
              receive_timeout: 120_000,
              seed: nil,
              n: 1,
              json_response: true,
              json_schema: nil,
              max_tokens: nil,
              tool_choice: nil,
              user: nil,
              messages: [],
              site_url: nil,
              site_name: nil,
              provider: nil,
              transforms: nil,
              route: nil
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :open_router_models, [])[:default] || "openai/gpt-4",
            api_key: Application.get_env(:lux, :api_keys)[:openrouter]
          },
          config
        )
      )

    do_call(prompt, tools, config, 0)
  end

  @doc """
  Lists all available models on OpenRouter with pricing information.

  Returns a list of model maps with id, name, pricing, context length, etc.

  ## Options

    * `:api_key` - OpenRouter API key (optional for listing models)

  ## Examples

      {:ok, models} = Lux.LLM.OpenRouter.list_models()
      Enum.each(models, fn m -> IO.puts(m["id"]) end)
  """
  def list_models(opts \\ []) do
    headers =
      [{"Content-Type", "application/json"}] ++
        case opts[:api_key] do
          nil -> []
          key -> [{"Authorization", "Bearer #{Lux.Config.resolve(key)}"}]
        end

    [url: @models_endpoint, headers: headers]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: %{"data" => models}}} ->
        {:ok, models}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Retrieves cost and stats for a specific generation by its ID.

  ## Examples

      {:ok, stats} = Lux.LLM.OpenRouter.get_generation_stats("gen-abc123", api_key: "sk-or-...")
  """
  def get_generation_stats(generation_id, opts \\ []) do
    api_key = opts[:api_key] || Application.get_env(:lux, :api_keys)[:openrouter]

    [
      url: "https://openrouter.ai/api/v1/generation?id=#{generation_id}",
      headers: [
        {"Authorization", "Bearer #{Lux.Config.resolve(api_key)}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  # Private implementation

  defp do_call(_prompt, _tools, _config, retry) when retry > @max_retries do
    {:error, :max_retries_exceeded}
  end

  defp do_call(prompt, tools, config, retry) do
    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        temperature: config.temperature,
        frequency_penalty: config.frequency_penalty,
        max_tokens: config.max_tokens
      }
      |> maybe_add_tools(tools_config, config.tool_choice)
      |> maybe_add_response_format(config)
      |> maybe_add_provider(config.provider)
      |> maybe_add_transforms(config.transforms)
      |> maybe_add_route(config.route)

    headers =
      [
        {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
        {"Content-Type", "application/json"}
      ] ++
        maybe_add_site_headers(config)

    [
      url: config.endpoint || @endpoint,
      json: body,
      headers: headers,
      receive_timeout: config.receive_timeout
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: 402}} ->
        {:error, :insufficient_credits}

      {:ok, %{status: 429} = response} ->
        handle_rate_limit(prompt, tools, config, retry, response)

      {:ok, %{status: 408}} ->
        Logger.warning("OpenRouter request timed out, retry #{retry + 1}/#{@max_retries}")
        retry_with_backoff(prompt, tools, config, retry)

      {:ok, %{status: 502}} ->
        Logger.warning("OpenRouter upstream error, retry #{retry + 1}/#{@max_retries}")
        retry_with_backoff(prompt, tools, config, retry)

      {:ok, %{status: 503}} ->
        Logger.warning("OpenRouter service unavailable, retry #{retry + 1}/#{@max_retries}")
        retry_with_backoff(prompt, tools, config, retry)

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, inspect(body)}}

      {:error, error} ->
        if retry < @max_retries do
          Logger.warning("OpenRouter request error: #{inspect(error)}, retry #{retry + 1}/#{@max_retries}")
          retry_with_backoff(prompt, tools, config, retry)
        else
          handle_error(error)
        end
    end
  end

  defp handle_rate_limit(prompt, tools, config, retry, response) do
    retry_after =
      case Req.Response.get_header(response, "retry-after") do
        [seconds | _] -> String.to_integer(seconds) * 1_000
        _ -> @base_retry_delay * :math.pow(2, retry) |> round()
      end

    Logger.warning("OpenRouter rate limited, waiting #{retry_after}ms before retry #{retry + 1}/#{@max_retries}")
    Process.sleep(retry_after)
    do_call(prompt, tools, config, retry + 1)
  end

  defp retry_with_backoff(prompt, tools, config, retry) do
    delay = @base_retry_delay * :math.pow(2, retry) |> round()
    Process.sleep(delay)
    do_call(prompt, tools, config, retry + 1)
  end

  defp build_messages(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &OpenAI.tool_to_function/1)

  defp maybe_add_tools(body, [], _tool_choice), do: body

  defp maybe_add_tools(body, tools, tool_choice) do
    body
    |> Map.put(:tools, tools)
    |> Map.put(:tool_choice, format_tool_choice(tool_choice))
  end

  defp format_tool_choice(:none), do: "none"
  defp format_tool_choice(:auto), do: "auto"

  defp format_tool_choice(name) when is_binary(name),
    do: %{"type" => "function", "function" => %{"name" => String.replace(name, ".", "_")}}

  defp format_tool_choice(_), do: "auto"

  defp maybe_add_response_format(body, %Config{json_response: false}) do
    Map.put(body, :response_format, %{type: "text"})
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_map(schema) do
    Map.put(body, :response_format, %{
      type: "json_schema",
      json_schema: schema
    })
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: nil}) do
    Map.put(
      %{
        body
        | messages:
            Enum.map(body.messages, &%{&1 | content: &1.content <> "\n Reply in json format"})
      },
      :response_format,
      %{type: "json_object"}
    )
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_atom(schema) do
    Map.put(body, :response_format, %{
      type: "json_schema",
      json_schema: %{name: schema.name(), schema: schema.schema()}
    })
  end

  defp maybe_add_response_format(body, _), do: Map.put(body, :response_format, %{type: "text"})

  defp maybe_add_provider(body, nil), do: body
  defp maybe_add_provider(body, provider) when is_map(provider), do: Map.put(body, :provider, provider)

  defp maybe_add_transforms(body, nil), do: body
  defp maybe_add_transforms(body, transforms) when is_list(transforms), do: Map.put(body, :transforms, transforms)

  defp maybe_add_route(body, nil), do: body
  defp maybe_add_route(body, route) when is_binary(route), do: Map.put(body, :route, route)

  defp maybe_add_site_headers(config) do
    []
    |> maybe_add_header("HTTP-Referer", config.site_url)
    |> maybe_add_header("X-Title", config.site_name)
  end

  defp maybe_add_header(headers, _name, nil), do: headers
  defp maybe_add_header(headers, name, value), do: [{name, value} | headers]

  defp handle_response(%{body: body}, config) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message, "finish_reason" => finish_reason} <- choice,
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls_results} <- OpenAI.execute_tool_calls(message["tool_calls"]) do
      payload = %{
        content: content,
        model: body["model"],
        finish_reason: finish_reason,
        tool_calls: message["tool_calls"],
        tool_calls_results: tool_calls_results
      }

      # OpenRouter includes extra metadata: generation ID, provider used, cost
      metadata =
        %{
          id: body["id"],
          created: body["created"],
          usage: body["usage"],
          system_fingerprint: body["system_fingerprint"]
        }
        |> maybe_add_cost(body)
        |> maybe_add_generation_id(body)
        |> maybe_add_provider_name(body)

      Logger.debug(
        "OpenRouter response via #{inspect(metadata[:provider_name])}, " <>
          "model: #{body["model"]}, " <>
          "tokens: #{inspect(body["usage"])}"
      )

      %{
        schema_id: ResponseSignal,
        payload: payload,
        metadata: metadata
      }
      |> Lux.Signal.new()
      |> ResponseSignal.validate()
    end
  end

  defp parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} -> {:ok, structured_output}
      {:error, _} -> {:ok, content}
    end
  end

  defp parse_content(_), do: {:ok, nil}

  defp maybe_add_cost(metadata, %{"usage" => %{"cost" => cost}}) when not is_nil(cost) do
    Map.put(metadata, :cost, cost)
  end

  defp maybe_add_cost(metadata, _), do: metadata

  defp maybe_add_generation_id(metadata, %{"id" => id}) when is_binary(id) do
    Map.put(metadata, :generation_id, id)
  end

  defp maybe_add_generation_id(metadata, _), do: metadata

  defp maybe_add_provider_name(metadata, %{"provider" => provider}) when is_binary(provider) do
    Map.put(metadata, :provider_name, provider)
  end

  defp maybe_add_provider_name(metadata, _), do: metadata

  defp handle_error(error) do
    Logger.error("OpenRouter API error: #{inspect(error)}")
    {:error, "OpenRouter API error: #{inspect(error)}"}
  end
end
