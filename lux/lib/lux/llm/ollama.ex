defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama local model support for self-hosted LLMs.
  Uses Ollama's OpenAI-compatible API endpoint.
  """
  @behaviour Lux.LLM

  alias Lux.LLM.ResponseSignal
  require Logger

  @endpoint "http://localhost:11434/v1/chat/completions"

  defmodule Config do
    @moduledoc """
    Configuration for Ollama.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            max_tokens: integer(),
            receive_timeout: integer(),
            keep_alive: String.t(),
            messages: [map()]
          }

    defstruct endpoint: "http://localhost:11434/v1/chat/completions",
              model: "llama3",
              api_key: nil,
              temperature: 0.7,
              max_tokens: nil,
              receive_timeout: 120_000,
              keep_alive: "5m",
              messages: []
  end

  @impl true
  def call(prompt, tools, config) do
    config = struct(Config, Map.merge(%{}, config))
    do_call(prompt, tools, config)
  end

  defp do_call(prompt, _tools, config) do
    messages = config.messages ++ build_messages(prompt)

    body = %{
      model: config.model,
      messages: messages,
      temperature: config.temperature,
      stream: false
    }

    body = if config.max_tokens, do: Map.put(body, :max_tokens, config.max_tokens), else: body
    body = if config.keep_alive, do: Map.put(body, :keep_alive, config.keep_alive), else: body

    headers = [{"Content-Type", "application/json"}]
    body = if config.api_key, do: body, else: body

    case HTTPoison.post(config.endpoint, Jason.encode!(body), headers, recv_timeout: config.receive_timeout) do
      {:ok, %{status_code: 200, body: response_body}} ->
        parse_response(response_body, config.model)

      {:ok, %{status_code: status, body: error_body}} ->
        {:error, "Ollama error (status #{status}): #{error_body}"}

      {:error, %{reason: reason}} ->
        {:error, "Ollama connection failed: #{reason}. Is Ollama running?"}
    end
  end

  defp build_messages(prompt) when is_binary(prompt), do: [%{role: "user", content: prompt}]
  defp build_messages(prompt) when is_list(prompt), do: prompt
  defp build_messages(prompt), do: [%{role: "user", content: inspect(prompt)}]

  defp parse_response(response_body, model) do
    case Jason.decode(response_body) do
      {:ok, %{"choices" => [choice | _]}} ->
        signal = %{
          schema_id: ResponseSignal,
          payload: %{
            content: choice["message"]["content"],
            model: model,
            finish_reason: choice["finish_reason"],
            usage: %{}
          },
          metadata: %{provider: :ollama, model: model}
        }
        case Lux.Signal.new(signal) |> ResponseSignal.validate() do
          {:ok, validated} -> {:ok, validated}
          {:error, error} -> {:error, "Signal validation failed: #{inspect(error)}"}
        end
      {:ok, _} -> {:error, "No choices in response"}
      {:error, error} -> {:error, "Failed to parse response: #{error}"}
    end
  end
end