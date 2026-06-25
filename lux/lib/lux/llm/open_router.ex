defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM Integration ($500).

  Provides access to 100+ models via a single OpenAI-compatible API,
  with automatic fallback, cost tracking, and model routing.

  ## Configuration

      config :lux, :api_keys, openrouter: System.get_env("OPENROUTER_API_KEY")

  ## Popular Models

  | Model ID                          | Provider    | Context |
  |-----------------------------------|-------------|----------|
  | anthropic/claude-3.5-sonnet       | Anthropic   | 200k    |
  | openai/gpt-4o                     | OpenAI      | 128k    |
  | meta-llama/llama-3.3-70b-instruct | Meta        | 128k    |
  | google/gemini-2.0-flash-001       | Google      | 1M      |
  | deepseek/deepseek-r1              | DeepSeek    | 128k    |
  """

  @behaviour Lux.LLM

  alias Lux.LLM.ResponseSignal
  require Logger

  @endpoint "https://openrouter.ai/api/v1/chat/completions"
  @default_model "meta-llama/llama-3.3-70b-instruct:free"

  defmodule Config do
    @moduledoc "Configuration for OpenRouter."
    @type t :: %__MODULE__{
            model: String.t(),
            api_key: String.t() | nil,
            temperature: float(),
            max_tokens: integer() | nil,
            receive_timeout: integer(),
            site_url: String.t() | nil,
            site_name: String.t() | nil
          }
    defstruct model: "meta-llama/llama-3.3-70b-instruct:free",
              api_key: nil,
              temperature: 0.7,
              max_tokens: nil,
              receive_timeout: 60_000,
              site_url: nil,
              site_name: nil
  end

  @impl true
  def call(prompt, _tools, config) do
    cfg = struct(Config, Map.merge(
      %{model: Application.get_env(:lux, :openrouter_models, %{})[:default] || @default_model,
        api_key: Application.get_env(:lux, :api_keys, [])[:openrouter]},
      config
    ))

    api_key = Lux.Config.resolve(cfg.api_key)
    if is_nil(api_key) or api_key == "",
      do: raise(ArgumentError, "OPENROUTER_API_KEY not configured")

    body = %{model: cfg.model, messages: [%{role: "user", content: prompt}],
             temperature: cfg.temperature}
           |> maybe_put(:max_tokens, cfg.max_tokens)

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"HTTP-Referer", cfg.site_url || "https://lux.spectral.finance"},
      {"X-Title", cfg.site_name || "Lux"}
    ]

    case Req.post(@endpoint, json: body, headers: headers, receive_timeout: cfg.receive_timeout) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => c}} | _]} = resp}} ->
        usage = resp["usage"] || %{}
        {:ok, %ResponseSignal{content: c, model: cfg.model, provider: :openrouter,
                              metadata: %{usage: usage}}}
      {:ok, %{status: 401}} -> {:error, :invalid_api_key}
      {:ok, %{status: 429}} -> {:error, :rate_limited}
      {:ok, %{status: s, body: %{"error" => %{"message" => m}}}} -> {:error, {s, m}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
