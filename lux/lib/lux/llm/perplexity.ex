defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI LLM implementation for knowledge-intensive tasks with built-in
  web search and citation support.

  Perplexity combines large language models with real-time web search to provide
  accurate, up-to-date, and cited responses.

  ## Features

  - Online models with real-time web search (sonar family)
  - Citation support with source URLs
  - Search domain filtering and recency controls
  - OpenAI-compatible API format
  - Automatic retry with exponential backoff

  ## Configuration

      config :lux, :api_keys, perplexity: "pplx-..."
      config :lux, :perplexity_models, default: "sonar-pro"

  ## Usage

      Lux.LLM.Perplexity.call("What happened in tech today?", [], %{
        model: "sonar-pro",
        api_key: "pplx-...",
        return_citations: true
      })
  """

  @behaviour Lux.LLM

  alias Lux.LLM.OpenAI
  alias Lux.LLM.ResponseSignal

  require Logger

  @endpoint "https://api.perplexity.ai/chat/completions"

  @max_retries 3
  @base_retry_delay 1_000

  defmodule Config do
    @moduledoc """
    Configuration module for Perplexity AI.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            frequency_penalty: float(),
            receive_timeout: integer(),
            n: integer(),
            json_response: boolean(),
            json_schema: map(),
            max_tokens: integer(),
            tool_choice: map(),
            messages: [map()],
            top_p: float() | nil,
            top_k: integer() | nil,
            presence_penalty: float() | nil,
            return_citations: boolean(),
            return_images: boolean(),
            return_related_questions: boolean(),
            search_domain_filter: [String.t()] | nil,
            search_recency_filter: String.t() | nil
          }

    defstruct endpoint: "https://api.perplexity.ai/chat/completions",
              model: "sonar-pro",
              api_key: nil,
              temperature: 0.2,
              frequency_penalty: 0.0,
              receive_timeout: 120_000,
              n: 1,
              json_response: true,
              json_schema: nil,
              max_tokens: nil,
              tool_choice: nil,
              messages: [],
              top_p: nil,
              top_k: nil,
              presence_penalty: nil,
              return_citations: true,
              return_images: false,
              return_related_questions: false,
              search_domain_filter: nil,
              search_recency_filter: nil
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :perplexity_models, [])[:default] || "sonar-pro",
            api_key: Application.get_env(:lux, :api_keys)[:perplexity]
          },
          config
        )
      )

    do_call(prompt, tools, config, 0)
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
      |> maybe_add_search_options(config)
      |> maybe_add_sampling(config)

    [
      url: config.endpoint || @endpoint,
      json: body,
      headers: [
        {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
        {"Content-Type", "application/json"}
      ],
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

      {:ok, %{status: 429} = response} ->
        handle_rate_limit(prompt, tools, config, retry, response)

      {:ok, %{status: status}} when status in [408, 502, 503] ->
        Logger.warning("Perplexity error #{status}, retry #{retry + 1}/#{@max_retries}")
        retry_with_backoff(prompt, tools, config, retry)

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, inspect(body)}}

      {:error, error} ->
        if retry < @max_retries do
          Logger.warning("Perplexity request error: #{inspect(error)}, retry #{retry + 1}/#{@max_retries}")
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

    Logger.warning("Perplexity rate limited, waiting #{retry_after}ms before retry #{retry + 1}/#{@max_retries}")
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
    body
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

  defp maybe_add_response_format(body, _), do: body

  defp maybe_add_search_options(body, config) do
    body
    |> maybe_put(:return_citations, config.return_citations)
    |> maybe_put(:return_images, config.return_images)
    |> maybe_put(:return_related_questions, config.return_related_questions)
    |> maybe_put(:search_domain_filter, config.search_domain_filter)
    |> maybe_put(:search_recency_filter, config.search_recency_filter)
  end

  defp maybe_add_sampling(body, config) do
    body
    |> maybe_put(:top_p, config.top_p)
    |> maybe_put(:top_k, config.top_k)
    |> maybe_put(:presence_penalty, config.presence_penalty)
  end

  defp maybe_put(body, _key, nil), do: body
  defp maybe_put(body, _key, false), do: body
  defp maybe_put(body, key, value), do: Map.put(body, key, value)

  defp handle_response(%{body: body}, _config) do
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

      metadata =
        %{
          id: body["id"],
          created: body["created"],
          usage: body["usage"]
        }
        |> maybe_add_citations(body)
        |> maybe_add_images(body)
        |> maybe_add_related_questions(body)

      Logger.debug(
        "Perplexity response, model: #{body["model"]}, " <>
          "citations: #{length(Map.get(metadata, :citations, []))}, " <>
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

  defp maybe_add_citations(metadata, %{"citations" => citations}) when is_list(citations) do
    Map.put(metadata, :citations, citations)
  end

  defp maybe_add_citations(metadata, _), do: metadata

  defp maybe_add_images(metadata, %{"images" => images}) when is_list(images) do
    Map.put(metadata, :images, images)
  end

  defp maybe_add_images(metadata, _), do: metadata

  defp maybe_add_related_questions(metadata, %{"related_questions" => questions}) when is_list(questions) do
    Map.put(metadata, :related_questions, questions)
  end

  defp maybe_add_related_questions(metadata, _), do: metadata

  defp handle_error(error) do
    Logger.error("Perplexity API error: #{inspect(error)}")
    {:error, "Perplexity API error: #{inspect(error)}"}
  end
end
