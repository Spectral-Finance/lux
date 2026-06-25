defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI LLM implementation.

  Provides access to Perplexity AI models including sonar, sonar-pro,
  and sonar-deep-research for knowledge-intensive tasks with
  real-time web search grounding.

  ## Configuration

      config :lux, :api_keys, perplexity: System.get_env("PERPLEXITY_API_KEY")

  ## Models

  | Model                  | Context | Best for                    |
  |------------------------|---------|-----------------------------|
  | sonar                  |  127k   | Fast Q&A with citations     |
  | sonar-pro              |  200k   | Complex research tasks      |
  | sonar-deep-research    |  200k   | Deep multi-step research    |
  """

  @behaviour Lux.LLM

  alias Lux.LLM.ResponseSignal
  require Logger

  @endpoint "https://api.perplexity.ai/chat/completions"
  @default_model "sonar"

  defmodule Config do
    @moduledoc "Configuration for Perplexity AI LLM."
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t() | nil,
            temperature: float(),
            max_tokens: integer() | nil,
            receive_timeout: integer(),
            return_citations: boolean(),
            search_recency_filter: String.t() | nil
          }
    defstruct endpoint: "https://api.perplexity.ai/chat/completions",
              model: "sonar",
              api_key: nil,
              temperature: 0.2,
              max_tokens: nil,
              receive_timeout: 60_000,
              return_citations: true,
              search_recency_filter: nil
  end

  @impl true
  def call(prompt, _tools, config) do
    cfg = struct(Config, Map.merge(
      %{model: Application.get_env(:lux, :perplexity_models, %{})[:default] || @default_model,
        api_key: Application.get_env(:lux, :api_keys, [])[:perplexity]},
      config
    ))

    api_key = Lux.Config.resolve(cfg.api_key)
    if is_nil(api_key) or api_key == "", do: raise(ArgumentError, "PERPLEXITY_API_KEY not configured")

    body = %{
      model: cfg.model,
      messages: [%{role: "user", content: prompt}],
      temperature: cfg.temperature,
      return_citations: cfg.return_citations
    }
    |> maybe_add_max_tokens(cfg.max_tokens)
    |> maybe_add_recency(cfg.search_recency_filter)

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    case Req.post(cfg.endpoint, json: body, headers: headers, receive_timeout: cfg.receive_timeout) do
      {:ok, %{status: 200, body: body}} ->
        parse_response(body, cfg.model)
      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}
      {:ok, %{status: 429}} ->
        {:error, :rate_limited}
      {:ok, %{status: status, body: %{"error" => %{"message" => msg}}}} ->
        {:error, {status, msg}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_response(%{"choices" => [%{"message" => %{"content" => content}} | _]} = body, model) do
    citations = Map.get(body, "citations", [])
    {:ok, %ResponseSignal{
      content: content,
      model: model,
      provider: :perplexity,
      metadata: %{citations: citations}
    }}
  end
  defp parse_response(body, _model), do: {:error, {:unexpected_response, body}}

  defp maybe_add_max_tokens(body, nil), do: body
  defp maybe_add_max_tokens(body, n), do: Map.put(body, :max_tokens, n)

  defp maybe_add_recency(body, nil), do: body
  defp maybe_add_recency(body, f), do: Map.put(body, :search_recency_filter, f)
end
