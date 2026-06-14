defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation that provides unified access to 200+ models
  (OpenAI, Anthropic, Google, Meta, Mistral, etc.) through a single
  OpenAI-compatible API endpoint.

  OpenRouter implements the OpenAI Chat Completions API spec, so requests
  and responses follow the same format as `Lux.LLM.OpenAI`.

  ## Configuration

      config :lux,
        api_keys: [openrouter: System.get_env("OPENROUTER_API_KEY")],
        open_router_models: [default: "openai/gpt-4o-mini"]

  ## Features
  - Access to 200+ models through one API key
  - Automatic fallback routing via the `models` list
  - Cost tracking via response usage metadata
  - Automatic retry with exponential backoff on rate limits (429) and
    server errors (5xx)
  - Supports Beams, Prisms and Lenses as tools (same as OpenAI)

  ## Example

      iex> Lux.LLM.OpenRouter.call("What is 2+2?", [], %{
      ...>   model: "openai/gpt-4o-mini"
      ...> })
  """

  @behaviour Lux.LLM

  alias Lux.LLM.OpenAI
  alias Lux.LLM.ResponseSignal

  require Logger

  @endpoint "https://openrouter.ai/api/v1/chat/completions"
  @max_retries 3

  defmodule Config do
    @moduledoc """
    Configuration module for OpenRouter.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            models: [String.t()] | nil,
            api_key: String.t(),
            temperature: float(),
            max_tokens: integer() | nil,
            json_response: boolean(),
            json_schema: map() | atom() | nil,
            tool_choice: term(),
            messages: [map()],
            site_url: String.t() | nil,
            app_name: String.t() | nil,
            receive_timeout: integer()
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: "openai/gpt-4o-mini",
              models: nil,
              api_key: nil,
              temperature: 0.7,
              max_tokens: nil,
              json_response: true,
              json_schema: nil,
              tool_choice: nil,
              messages: [],
              site_url: nil,
              app_name: "Lux",
              receive_timeout: 60_000
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :open_router_models)[:default] || "openai/gpt-4o-mini",
            api_key: Application.get_env(:lux, :api_keys)[:openrouter]
          },
          config
        )
      )

    messages = config.messages ++ [%{role: "user", content: prompt}]
    tools_config = Enum.map(tools, &OpenAI.tool_to_function/1)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        temperature: config.temperature
      }
      |> maybe_add_models(config.models)
      |> maybe_add_max_tokens(config.max_tokens)
      |> maybe_add_tools(tools_config, config.tool_choice)
      |> maybe_add_response_format(config)

    headers = build_headers(config)

    do_request(body, headers, config, 0)
  end

  defp build_headers(config) do
    [
      {"Authorization", "Bearer " <> Lux.Config.resolve(config.api_key)},
      {"Content-Type", "application/json"}
    ]
    |> maybe_add_header("HTTP-Referer", config.site_url)
    |> maybe_add_header("X-Title", config.app_name)
  end

  defp maybe_add_header(headers, _key, nil), do: headers
  defp maybe_add_header(headers, key, value), do: headers ++ [{key, value}]

  defp maybe_add_models(body, nil), do: body
  defp maybe_add_models(body, []), do: body
  defp maybe_add_models(body, models) when is_list(models), do: Map.put(body, :models, models)
  defp maybe_add_models(body, _), do: body

  defp maybe_add_max_tokens(body, nil), do: body
  defp maybe_add_max_tokens(body, max_tokens), do: Map.put(body, :max_tokens, max_tokens)

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

  defp maybe_add_response_format(body, %Config{json_response: false}), do: body

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_map(schema) do
    Map.put(body, :response_format, %{type: "json_schema", json_schema: schema})
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_atom(schema) and not is_nil(schema) do
    Map.put(body, :response_format, %{
      type: "json_schema",
      json_schema: %{name: schema.name(), schema: schema.schema()}
    })
  end

  defp maybe_add_response_format(body, %Config{json_response: true}) do
    Map.put(body, :response_format, %{type: "json_object"})
  end

  defp maybe_add_response_format(body, _), do: body

  # Retries on 429 (rate limit) and 5xx errors with exponential backoff
  defp do_request(body, headers, config, attempt) do
    [url: @endpoint, json: body, headers: headers, receive_timeout: config.receive_timeout]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: 429}} when attempt < @max_retries ->
        retry(body, headers, config, attempt, "rate limited (429)")

      {:ok, %{status: status}} when status >= 500 and attempt < @max_retries ->
        retry(body, headers, config, attempt, "server error (#{status})")

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {status, inspect(resp_body)}}

      {:error, error} ->
        Logger.error("OpenRouter API error: " <> inspect(error))
        {:error, "OpenRouter API error: " <> inspect(error)}
    end
  end

  defp retry(body, headers, config, attempt, reason) do
    backoff = round(:math.pow(2, attempt) * 1000)
    Logger.warning("OpenRouter " <> reason <> ", retrying in " <> Integer.to_string(backoff) <> "ms")
    Process.sleep(backoff)
    do_request(body, headers, config, attempt + 1)
  end

  defp handle_response(%{body: body}, _config) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message} = choice,
         {:ok, content} <- OpenAI.parse_content(message["content"]),
         {:ok, tool_calls_results} <- OpenAI.execute_tool_calls(message["tool_calls"]) do
      usage = body["usage"] || %{}

      payload = %{
        content: content,
        model: body["model"],
        finish_reason: choice["finish_reason"] || choice["native_finish_reason"],
        tool_calls: message["tool_calls"],
        tool_calls_results: tool_calls_results
      }

      metadata = %{
        id: body["id"],
        created: body["created"],
        usage: usage,
        cost: usage["cost"],
        provider: body["provider"]
      }

      %{schema_id: ResponseSignal, payload: payload, metadata: metadata}
      |> Lux.Signal.new()
      |> ResponseSignal.validate()
    end
  end
end