defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation for local self-hosted models.

  Enables self-hosted LLM inference via the Ollama REST API,
  supporting any model downloaded to the local Ollama instance.

  ## Configuration

      config :lux, Lux.LLM.Ollama,
        endpoint: "http://localhost:11434",
        model: "llama3.2",
        receive_timeout: 120_000

  ## Usage

      {:ok, response} = Lux.LLM.Ollama.call(
        "Explain concentrated liquidity",
        [],
        %{model: "llama3.2", temperature: 0.7}
      )
  """

  @behaviour Lux.LLM

  alias Lux.LLM.ResponseSignal
  require Logger

  @default_endpoint "http://localhost:11434"
  @chat_path "/api/chat"

  defmodule Config do
    @moduledoc "Configuration for Ollama LLM."
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            temperature: float(),
            receive_timeout: integer(),
            max_tokens: integer() | nil,
            stream: boolean()
          }
    defstruct endpoint: "http://localhost:11434",
              model: "llama3.2",
              temperature: 0.7,
              receive_timeout: 120_000,
              max_tokens: nil,
              stream: false
  end

  @impl true
  def call(prompt, _tools, config) do
    cfg = struct(Config, Map.merge(
      %{endpoint: Application.get_env(:lux, __MODULE__, [])[:endpoint] || @default_endpoint,
        model: Application.get_env(:lux, __MODULE__, [])[:model] || "llama3.2"},
      config
    ))

    body = %{
      model: cfg.model,
      messages: [%{role: "user", content: prompt}],
      stream: cfg.stream,
      options: %{temperature: cfg.temperature}
    } |> maybe_add_max_tokens(cfg.max_tokens)

    url = cfg.endpoint <> @chat_path

    case Req.post(url, json: body, receive_timeout: cfg.receive_timeout) do
      {:ok, %{status: 200, body: %{"message" => %{"content" => content}}}} ->
        {:ok, %ResponseSignal{content: content, model: cfg.model, provider: :ollama}}
      {:ok, %{status: 200, body: %{"error" => err}}} ->
        {:error, err}
      {:ok, %{status: status, body: body}} ->
        Logger.error("Ollama HTTP #{status}: #{inspect(body)}")
        {:error, {status, body}}
      {:error, %{reason: :econnrefused}} ->
        {:error, :ollama_not_running}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_add_max_tokens(body, nil), do: body
  defp maybe_add_max_tokens(body, n), do: put_in(body, [:options, :num_predict], n)
end
