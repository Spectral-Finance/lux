defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI LLM implementation for knowledge-intensive tasks with real-time web search.

  Perplexity provides access to powerful language models that can perform web searches
  in real-time, making them ideal for tasks requiring up-to-date information.

  ## Models

  ### Online Models (with web search)
  - `sonar` — Perplexity's flagship online model with real-time search
  - `sonar-pro` — Enhanced online model with deeper reasoning
  - `sonar-reasoning` — Online model optimized for structured reasoning tasks
  - `sonar-reasoning-pro` — Premium reasoning with advanced search capabilities

  ### Offline Models (no web search)
  - `sonar-chat` — Conversational model without search
  - `r1-1776` — DeepSeek R1 finetuned for unfiltered outputs

  ## Configuration

      config :lux, :perplexity,
        api_key: "pplx-...",
        default_model: "sonar"

  ## Features

  - **Real-time web search** (online models): Automatically searches the web to answer queries
  - **Citations**: Online models return sources used in their responses
  - **Streaming**: Supports streaming responses for reduced latency
  - **Search domain filter**: Restrict search to specific domains
  - **Recency filter**: Filter results by time (month, week, day, hour)

  ## Example

      iex> Lux.LLM.Perplexity.call(
      ...>   "What are the latest Solana validator updates?",
      ...>   [],
      ...>   %{model: "sonar", json_response: false}
      ...> )
      {:ok, %Lux.Signal{
        payload: %{
          content: "The latest Solana validator updates include...",
          citations: ["https://docs.solana.com/...", ...],
          model: "sonar"
        }
      }}
  """

  @behaviour Lux.LLM

  alias Lux.LLM.ResponseSignal

  require Logger

  @endpoint "https://api.perplexity.ai/chat/completions"

  @online_models ~w(sonar sonar-pro sonar-reasoning sonar-reasoning-pro)
  @valid_recency_filters ~w(month week day hour)

  defmodule Config do
    @moduledoc """
    Configuration for the Perplexity AI LLM client.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t() | nil,
            temperature: float(),
            receive_timeout: integer(),
            max_tokens: integer() | nil,
            json_response: boolean(),
            messages: [map()],
            search_domain_filter: [String.t()],
            return_images: boolean(),
            return_related_questions: boolean(),
            search_recency_filter: String.t() | nil,
            presence_penalty: float(),
            frequency_penalty: float()
          }

    defstruct endpoint: "https://api.perplexity.ai/chat/completions",
              model: "sonar",
              api_key: nil,
              temperature: 0.2,
              receive_timeout: 60_000,
              max_tokens: nil,
              json_response: false,
              messages: [],
              search_domain_filter: [],
              return_images: false,
              return_related_questions: false,
              search_recency_filter: nil,
              presence_penalty: 0.0,
              frequency_penalty: 1.0
  end

  @impl true
  def call(prompt, _tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model:
              Application.get_env(:lux, :perplexity, [])[:default_model] || "sonar",
            api_key: Application.get_env(:lux, :perplexity, [])[:api_key]
          },
          config
        )
      )

    messages = config.messages ++ build_messages(prompt)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        temperature: config.temperature,
        frequency_penalty: config.frequency_penalty,
        presence_penalty: config.presence_penalty
      }
      |> maybe_add_max_tokens(config.max_tokens)
      |> maybe_add_search_options(config)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    [
      url: @endpoint,
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

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Returns true if the given model supports real-time web search.

  ## Example

      iex> Lux.LLM.Perplexity.online_model?("sonar")
      true

      iex> Lux.LLM.Perplexity.online_model?("sonar-chat")
      false
  """
  def online_model?(model) when is_binary(model) do
    Enum.any?(@online_models, &String.starts_with?(model, &1))
  end

  @doc """
  Returns the list of available online (web-search-enabled) models.
  """
  def online_models, do: @online_models

  @doc """
  Validates a search recency filter value.

  Valid values: "month", "week", "day", "hour"

  ## Example

      iex> Lux.LLM.Perplexity.valid_recency_filter?("week")
      true

      iex> Lux.LLM.Perplexity.valid_recency_filter?("year")
      false
  """
  def valid_recency_filter?(filter) when is_binary(filter) do
    filter in @valid_recency_filters
  end

  # Private helpers

  defp build_messages(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp maybe_add_max_tokens(body, nil), do: body
  defp maybe_add_max_tokens(body, max), do: Map.put(body, :max_tokens, max)

  defp maybe_add_search_options(body, %Config{search_domain_filter: [], search_recency_filter: nil, return_images: false, return_related_questions: false}) do
    body
  end

  defp maybe_add_search_options(body, config) do
    body
    |> maybe_put(:search_domain_filter, config.search_domain_filter, &(length(&1) > 0))
    |> maybe_put(:return_images, config.return_images, &(&1 == true))
    |> maybe_put(:return_related_questions, config.return_related_questions, &(&1 == true))
    |> maybe_put(:search_recency_filter, config.search_recency_filter, &(not is_nil(&1)))
  end

  defp maybe_put(map, _key, value, condition) do
    if condition.(value), do: Map.put(map, _key, value), else: map
  end

  defp handle_response(%{body: body}, config) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message, "finish_reason" => finish_reason} <- choice,
         {:ok, content} <- parse_content(message["content"], config) do
      citations = Map.get(body, "citations", [])
      usage = body["usage"] || %{}

      payload = %{
        content: content,
        model: body["model"],
        finish_reason: finish_reason,
        citations: citations,
        tool_calls: nil,
        tool_calls_results: nil
      }

      metadata = %{
        id: body["id"],
        created: body["created"],
        usage: usage,
        system_fingerprint: Map.get(body, "system_fingerprint")
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

  defp parse_content(content, %Config{json_response: false}) when is_binary(content) do
    # Wrap plain text in a map to satisfy the ResponseSignal schema (content must be object or null)
    {:ok, %{"text" => content}}
  end

  defp parse_content(content, _config) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured} when is_map(structured) -> {:ok, structured}
      {:ok, value} -> {:ok, %{"value" => value}}
      {:error, _} -> {:error, "failed to parse JSON content: #{inspect(content)}"}
    end
  end

  defp parse_content(_, _), do: {:ok, nil}

  defp handle_error(error) do
    Logger.error("Perplexity API error: #{inspect(error)}")
    {:error, "Perplexity API error: #{inspect(error)}"}
  end
end
