defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI LLM implementation with search-grounded responses and citation support.

  Perplexity uses an OpenAI-compatible API but does not support function/tool calling.
  Supports search domain filtering, citations, and streaming.
  """

  @behaviour Lux.LLM

  alias Lux.LLM.ResponseSignal

  require Logger

  @endpoint "https://api.perplexity.ai/chat/completions"

  defmodule Config do
    @moduledoc """
    Configuration module for Perplexity AI.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            top_p: float(),
            max_tokens: integer(),
            presence_penalty: float(),
            frequency_penalty: float(),
            return_citations: boolean(),
            search_domain_filter: [String.t()],
            return_images: boolean(),
            stream: boolean(),
            receive_timeout: integer(),
            user: String.t(),
            messages: [map()]
          }

    defstruct endpoint: "https://api.perplexity.ai/chat/completions",
              model: "sonar-pro",
              api_key: nil,
              temperature: 0.7,
              top_p: nil,
              max_tokens: nil,
              presence_penalty: 0.0,
              frequency_penalty: 1.0,
              return_citations: true,
              search_domain_filter: nil,
              return_images: false,
              stream: false,
              receive_timeout: 60_000,
              user: nil,
              messages: []
  end

  @impl true
  def call(prompt, _tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: (Application.get_env(:lux, :perplexity_models) || %{})[:default],
            api_key: Application.get_env(:lux, :api_keys, [])[:perplexity]
          },
          config
        )
      )

    messages = config.messages ++ build_messages(prompt)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        temperature: config.temperature
      }
      |> maybe_add(:top_p, config.top_p)
      |> maybe_add(:max_tokens, config.max_tokens)
      |> maybe_add(:presence_penalty, config.presence_penalty)
      |> maybe_add(:frequency_penalty, config.frequency_penalty)
      |> maybe_add(:return_citations, config.return_citations)
      |> maybe_add(:search_domain_filter, config.search_domain_filter)
      |> maybe_add(:return_images, config.return_images)
      |> maybe_add(:stream, config.stream)

    [
      url: config.endpoint,
      json: body,
      headers: [
        {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  defp build_messages(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp maybe_add(body, _key, nil), do: body
  defp maybe_add(body, key, value), do: Map.put(body, key, value)

  defp handle_response(%{body: body}) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message, "finish_reason" => finish_reason} <- choice,
         {:ok, content} <- parse_content(message["content"]) do
      citations = Map.get(body, "citations", [])

      payload = %{
        content: content,
        model: body["model"],
        finish_reason: finish_reason,
        tool_calls: nil,
        tool_calls_results: nil
      }

      metadata = %{
        id: body["id"],
        created: body["created"],
        usage: body["usage"],
        citations: citations
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

  defp handle_error(error) do
    Logger.error("Perplexity AI API error: #{inspect(error)}")
    {:error, "Perplexity AI API error: #{inspect(error)}"}
  end
end
