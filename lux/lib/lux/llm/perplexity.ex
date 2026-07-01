defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI LLM implementation using their OpenAI-compatible API.
  Supports search-grounded chat completions.
  """
  @behaviour Lux.LLM

  alias Lux.LLM.ResponseSignal
  require Logger

  @endpoint "https://api.perplexity.ai/chat/completions"

  defmodule Config do
    @moduledoc """
    Configuration for Perplexity AI.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            max_tokens: integer(),
            receive_timeout: integer(),
            search_context: String.t(),
            messages: [map()]
          }

    defstruct endpoint: "https://api.perplexity.ai/chat/completions",
              model: "sonar-pro",
              api_key: nil,
              temperature: 0.7,
              max_tokens: nil,
              receive_timeout: 60_000,
              search_context: nil,
              messages: []
  end

  @impl true
  def call(prompt, _tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            api_key: Application.get_env(:lux, :api_keys)[:perplexity]
          },
          config
        )
      )

    if is_nil(config.api_key) do
      {:error, "Perplexity API key not configured. Set :api_keys :perplexity in config."}
    else
      make_request(prompt, config)
    end
  end

  defp make_request(prompt, config) do
    messages = config.messages ++ build_messages(prompt)

    body = %{
      model: config.model,
      messages: messages,
      temperature: config.temperature
    }

    body = if config.max_tokens, do: Map.put(body, :max_tokens, config.max_tokens), else: body
    body = if config.search_context, do: Map.put(body, :search_context, config.search_context), else: body

    headers = [
      {"Authorization", "Bearer #{config.api_key}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.post(config.endpoint, Jason.encode!(body), headers, recv_timeout: config.receive_timeout) do
      {:ok, %{status_code: 200, body: response_body}} ->
        parse_response(response_body, config)

      {:ok, %{status_code: status, body: error_body}} ->
        {:error, "Perplexity API error (status #{status}): #{error_body}"}

      {:error, %{reason: reason}} ->
        {:error, "HTTP request failed: #{reason}"}
    end
  end

  defp build_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_messages(prompt) when is_list(prompt) do
    prompt
  end

  defp build_messages(prompt), do: [%{role: "user", content: inspect(prompt)}]

  defp parse_response(response_body, _config) do
    case Jason.decode(response_body) do
      {:ok, data} ->
        choices = data["choices"]
        if choices && length(choices) > 0 do
          message = hd(choices)["message"]
          content = message["content"]
          citations = Map.get(data, "citations", [])

          payload = %{
            content: content,
            model: data["model"],
            finish_reason: hd(choices)["finish_reason"],
            citations: citations,
            usage: data["usage"]
          }

          signal = %{
            schema_id: ResponseSignal,
            payload: payload,
            metadata: %{
              provider: :perplexity,
              citations: citations
            }
          }

          case Lux.Signal.new(signal) |> ResponseSignal.validate() do
            {:ok, validated} -> {:ok, validated}
            {:error, error} -> {:error, "Signal validation failed: #{inspect(error)}"}
          end
        else
          {:error, "No choices in Perplexity response"}
        end

      {:error, error} ->
        {:error, "Failed to parse response: #{error}"}
    end
  end
end