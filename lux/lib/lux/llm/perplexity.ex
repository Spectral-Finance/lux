defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI LLM implementation that is OpenAI compatible.
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
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
            frequency_penalty: float(),
            receive_timeout: integer(),
            max_tokens: integer(),
            messages: [map()]
          }

    defstruct endpoint: "https://api.perplexity.ai/chat/completions",
              model: "sonar",
              api_key: nil,
              temperature: 0.7,
              frequency_penalty: 0.0,
              receive_timeout: 60_000,
              max_tokens: nil,
              messages: []
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :perplexity_models)[:default],
            api_key: Application.get_env(:lux, :api_keys)[:perplexity]
          },
          config
        )
      )

    messages = config.messages ++ build_messages(prompt)
    # Perplexity sonar models might not support advanced tool-calling or specific response formats,
    # but we'll provide standard compatibility layer just in case, while prioritizing simple text completions.
    body = %{
      model: Lux.Config.resolve(config.model),
      messages: messages,
      temperature: config.temperature,
      frequency_penalty: config.frequency_penalty,
      max_tokens: config.max_tokens
    }

    [
      url: @endpoint,
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
        handle_response(response, config)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:error, error} ->
        handle_error(error)
    end
  end

  defp build_messages(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp handle_response(%{body: body}, _config) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message, "finish_reason" => finish_reason} <- choice do
      payload = %{
        content: message["content"],
        model: body["model"],
        finish_reason: finish_reason,
        tool_calls: nil,
        tool_calls_results: nil
      }

      metadata = %{
        id: body["id"],
        created: body["created"],
        usage: body["usage"],
        system_fingerprint: body["system_fingerprint"]
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

  defp handle_error(error) do
    Logger.error("Perplexity API error: #{inspect(error)}")
    {:error, "Perplexity API error: #{inspect(error)}"}
  end
end
