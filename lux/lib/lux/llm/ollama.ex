defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation for local model inference.

  Ollama uses an OpenAI-compatible API running on localhost.
  Does not require an API key for local usage.
  """

  @behaviour Lux.LLM

  alias Lux.LLM.ResponseSignal

  require Logger

  @endpoint "http://localhost:11434/v1/chat/completions"

  defmodule Config do
    @moduledoc """
    Configuration module for Ollama.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            top_p: float(),
            max_tokens: integer(),
            stream: boolean(),
            receive_timeout: integer(),
            keep_alive: String.t(),
            messages: [map()]
          }

    defstruct endpoint: "http://localhost:11434/v1/chat/completions",
              model: "llama3.2",
              api_key: nil,
              temperature: 0.7,
              top_p: nil,
              max_tokens: nil,
              stream: false,
              receive_timeout: 120_000,
              keep_alive: "5m",
              messages: []
  end

  @impl true
  def call(prompt, _tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: (Application.get_env(:lux, :ollama_models) || %{})[:default],
            api_key: Application.get_env(:lux, :api_keys, [])[:ollama]
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
        stream: config.stream
      }
      |> maybe_add(:top_p, config.top_p)
      |> maybe_add(:max_tokens, config.max_tokens)
      |> maybe_add(:keep_alive, config.keep_alive)

    headers =
      if config.api_key do
        [{"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"}, {"Content-Type", "application/json"}]
      else
        [{"Content-Type", "application/json"}]
      end

    [
      url: config.endpoint,
      json: body,
      headers: headers
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response)

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
        usage: body["usage"]
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
    Logger.error("Ollama API error: #{inspect(error)}")
    {:error, "Ollama API error: #{inspect(error)}"}
  end
end
