defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI LLM implementation.

  Perplexity provides access to advanced language models with integrated web search
  capabilities, making it ideal for knowledge-intensive tasks that require
  up-to-date information.

  ## Features
  - Web search augmented generation
  - Citation support in responses
  - Specialized models for research and analysis
  - Streaming support
  - Sonar and online model variants

  ## Configuration
  Set your Perplexity API key in config:

      config :lux, :api_keys, perplexity: "pplx-..."
  """

  @behaviour Lux.LLM

  alias Lux.LLM.Response

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
            max_tokens: integer(),
            top_p: float(),
            frequency_penalty: float(),
            presence_penalty: float(),
            receive_timeout: integer(),
            search_context_size: String.t(),
            return_citations: boolean(),
            return_images: boolean(),
            return_related_questions: boolean(),
            user: String.t(),
            messages: [map()]
          }

    defstruct endpoint: "https://api.perplexity.ai/chat/completions",
              model: "sonar-pro",
              api_key: nil,
              temperature: 0.7,
              max_tokens: 4096,
              top_p: 0.9,
              frequency_penalty: 1.0,
              presence_penalty: 0.0,
              receive_timeout: 60_000,
              search_context_size: "high",
              return_citations: true,
              return_images: false,
              return_related_questions: false,
              user: nil,
              messages: []
  end

  @doc """
  Call Perplexity AI with the given prompt and options.

  Note: Perplexity does not support tool/function calling.
  Tools passed to this provider are logged but ignored.
  """
  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            api_key: Application.get_env(:lux, :api_keys)[:perplexity],
            model: Application.get_env(:lux, :perplexity_models)[:default]
          },
          config
        )
      )

    if tools != [] do
      Logger.warning("Perplexity provider does not support tool calling. Tools will be ignored.")
    end

    messages = config.messages ++ build_messages(prompt)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        temperature: config.temperature,
        max_tokens: config.max_tokens,
        top_p: config.top_p,
        frequency_penalty: config.frequency_penalty,
        presence_penalty: config.presence_penalty
      }
      |> maybe_add_search_params(config)

    case make_request(config, body) do
      {:ok, response} ->
        handle_response(response, config)

      {:error, reason} ->
        {:error, "Perplexity request failed: #{reason}"}
    end
  end

  # ── Search parameters ────────────────────────────────────────────────

  defp maybe_add_search_params(body, config) do
    body
    |> Map.put("search_context_size", config.search_context_size)
    |> then(fn b ->
      if config.return_citations, do: Map.put(b, "return_citations", true), else: b
    end)
    |> then(fn b ->
      if config.return_images, do: Map.put(b, "return_images", true), else: b
    end)
    |> then(fn b ->
      if config.return_related_questions, do: Map.put(b, "return_related_questions", true), else: b
    end)
  end

  # ── HTTP request ─────────────────────────────────────────────────────

  defp make_request(config, body) do
    req =
      [
        url: config.endpoint,
        json: body,
        headers: [
          {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
          {"Content-Type", "application/json"}
        ],
        receive_timeout: config.receive_timeout
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> Req.new()

    case Req.post(req) do
      {:ok, %{status: 200} = response} ->
        {:ok, response}

      {:ok, %{status: status} = response} ->
        error_msg = get_in(response.body, ["error", "message"]) || "HTTP #{status}"
        {:error, error_msg}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, "request timed out"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  # ── Response handling ────────────────────────────────────────────────

  defp handle_response(response, _config) do
    %{"choices" => choices} = response.body
    choice = List.first(choices)
    message = choice["message"]

    # Extract citations if available
    citations = Map.get(response.body, "citations", [])

    # Build content with citations appended
    content = build_content_with_citations(message["content"], citations)

    response_signal = %Response{
      content: content,
      tool_calls: [],
      finish_reason: choice["finish_reason"]
    }

    {:ok, response_signal}
  end

  defp build_content_with_citations(content, []) do
    content
  end

  defp build_content_with_citations(content, citations) do
    citation_text =
      citations
      |> Enum.with_index(1)
      |> Enum.map(fn {url, i} -> "[#{i}] #{url}" end)
      |> Enum.join("\n")

    content <> "\n\n---\n**Sources:**\n" <> citation_text
  end

  # ── Message building ─────────────────────────────────────────────────

  defp build_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_messages(messages) when is_list(messages) do
    messages
  end
end
