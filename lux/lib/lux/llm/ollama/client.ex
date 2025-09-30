defmodule Lux.LLM.Ollama.Client do
  @moduledoc """
  Thin HTTP client wrapper around the Ollama REST API. Uses `Req` so tests can
  substitute the transport layer with `Req.Test`.
  """

  alias Lux.Config

  @chat_path "/api/chat"
  @tags_path "/api/tags"
  @pull_path "/api/pull"

  @default_timeout 30_000

  @spec chat(map(), map()) :: {:ok, map()} | {:error, term()}
  def chat(config, body) do
    request_opts =
      [
        url: build_url(config.endpoint, @chat_path),
        json: body,
        headers: [{"content-type", "application/json"}],
        receive_timeout: config.request_timeout || @default_timeout
      ]
      |> with_defaults(__MODULE__)

    request_opts
    |> Req.new()
    |> Req.post()
  end

  @spec list_models(String.t(), map()) :: {:ok, list()} | {:error, term()}
  def list_models(endpoint, _config) do
    [url: build_url(endpoint, @tags_path)]
    |> with_defaults(__MODULE__)
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: %{"models" => models}}} -> {:ok, models}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec pull_model(String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def pull_model(endpoint, model, config) do
    body = %{model: model}

    [
      url: build_url(endpoint, @pull_path),
      json: body,
      receive_timeout: config.pull_timeout || max(config.request_timeout || @default_timeout, 120_000)
    ]
    |> with_defaults(__MODULE__)
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: %{"status" => "success"} = body}} ->
        ttl = config.model_ttl || Lux.LLM.Ollama.default(:model_ttl)

        {:ok,
         %{
           model: model,
           digest: Map.get(body, "digest"),
           size: Map.get(body, "size"),
           pulled_at: System.monotonic_time(:millisecond),
           last_used_at: System.monotonic_time(:millisecond),
           ttl: ttl
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} -> {:error, reason}
    end
  end

  defp with_defaults(opts, key) do
    env_opts =
      :lux
      |> Application.get_env(key, [])
      |> List.wrap()
      |> Enum.map(fn
        {k, v} -> {k, Config.resolve(v)}
        other -> other
      end)

    opts
    |> Keyword.merge(env_opts)
  end

  defp build_url(endpoint, path) do
    base =
      endpoint
      |> Kernel.||("http://localhost:11434")
      |> Config.resolve()
      |> to_string()

    URI.merge(base, path) |> URI.to_string()
  end
end
