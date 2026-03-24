defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama provider for local LLM support.

  Enables self-hosted LLM capabilities with optimized performance for local models.
  Supports model management, caching, and resource controls.

  ## Features

  - Local model support via Ollama
  - Model download and caching
  - Resource management
  - Performance optimization
  - No API costs (self-hosted)

  ## Configuration

  Add to your config:

      config :lux, :ollama,
        host: "http://localhost:11434",
        default_model: "llama2",
        timeout: 120_000,
        max_retries: 3

  ## Usage

      # Basic call
      {:ok, response} = Lux.LLM.Ollama.call("Hello!", [], %{})

      # With specific model
      {:ok, response} = Lux.LLM.Ollama.call("Hello!", [], %{model: "llama2"})

      # List available models
      {:ok, models} = Lux.LLM.Ollama.list_models()

      # Pull a new model
      {:ok, :pulling} = Lux.LLM.Ollama.pull_model("mistral")

  """

  alias Lux.LLM.ProviderRegistry

  @default_host "http://localhost:11434"
  @default_timeout 120_000
  @default_model "llama2"

  @doc """
  Call the Ollama API with a prompt.

  ## Options

    * `:model` - Model to use (default: "llama2")
    * `:host` - Ollama host (default: "http://localhost:11434")
    * `:timeout` - Request timeout (default: 120_000ms)
    * `:stream` - Enable streaming (default: false)
    * `:temperature` - Sampling temperature (default: 0.7)
    * `:max_tokens` - Maximum tokens to generate

  ## Examples

      iex> Lux.LLM.Ollama.call("Hello!", [], %{})
      {:ok, %Lux.LLM.Response{...}}

      iex> Lux.LLM.Ollama.call("Write a poem", [], %{model: "mistral"})
      {:ok, %Lux.LLM.Response{...}}

  """
  @spec call(String.t(), list(), map()) :: {:ok, map()} | {:error, term()}
  def call(prompt, tools, opts \\ %{}) do
    host = Map.get(opts, :host, get_host())
    model = Map.get(opts, :model, @default_model)
    timeout = Map.get(opts, :timeout, @default_timeout)

    url = "#{host}/api/generate"

    body = %{
      model: model,
      prompt: prompt,
      stream: Map.get(opts, :stream, false),
      options: %{
        temperature: Map.get(opts, :temperature, 0.7),
        num_predict: Map.get(opts, :max_tokens, 2048)
      }
    }

    headers = [{"Content-Type", "application/json"}]

    case make_request(:post, url, body, headers, timeout) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        handle_success_response(response_body, model)

      {:ok, %Req.Response{status: status, body: error_body}} ->
        {:error, {:api_error, status, error_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  List available models from Ollama.

  ## Examples

      iex> Lux.LLM.Ollama.list_models()
      {:ok, ["llama2", "mistral", "codellama"]}

  """
  @spec list_models(keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def list_models(opts \\ []) do
    host = Keyword.get(opts, :host, get_host())
    url = "#{host}/api/tags"

    case make_request(:get, url, nil, [], 30_000) do
      {:ok, %Req.Response{status: 200, body: %{"models" => models}}} ->
        model_names = Enum.map(models, fn %{"name" => name} -> name end)
        {:ok, model_names}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:api_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Pull a model from Ollama registry.

  ## Examples

      iex> Lux.LLM.Ollama.pull_model("mistral")
      {:ok, :pulling}

  """
  @spec pull_model(String.t(), keyword()) :: {:ok, :pulling} | {:error, term()}
  def pull_model(model_name, opts \\ []) do
    host = Keyword.get(opts, :host, get_host())
    url = "#{host}/api/pull"

    body = %{name: model_name}

    case make_request(:post, url, body, [{"Content-Type", "application/json"}], 300_000) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, :pulling}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:api_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get model information.

  ## Examples

      iex> Lux.LLM.Ollama.get_model_info("llama2")
      {:ok, %{size: "4.7GB", ...}}

  """
  @spec get_model_info(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_model_info(model_name, opts \\ []) do
    host = Keyword.get(opts, :host, get_host())
    url = "#{host}/api/show"

    body = %{name: model_name}

    case make_request(:post, url, body, [{"Content-Type", "application/json"}], 30_000) do
      {:ok, %Req.Response{status: 200, body: info}} ->
        {:ok, info}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:api_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Delete a model.

  ## Examples

      iex> Lux.LLM.Ollama.delete_model("old_model")
      :ok

  """
  @spec delete_model(String.t(), keyword()) :: :ok | {:error, term()}
  def delete_model(model_name, opts \\ []) do
    host = Keyword.get(opts, :host, get_host())
    url = "#{host}/api/delete"

    body = %{name: model_name}

    case make_request(:delete, url, body, [{"Content-Type", "application/json"}], 30_000) do
      {:ok, %Req.Response{status: 200}} ->
        :ok

      {:ok, %Req.Response{status: status}} ->
        {:error, {:api_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if Ollama server is running.

  ## Examples

      iex> Lux.LLM.Ollama.health_check()
      :ok

  """
  @spec health_check(keyword()) :: :ok | {:error, term()}
  def health_check(opts \\ []) do
    host = Keyword.get(opts, :host, get_host())
    url = "#{host}/api/tags"

    case make_request(:get, url, nil, [], 5_000) do
      {:ok, %Req.Response{status: 200}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Register Ollama as a provider.

  This allows Ollama to be used through the Provider abstraction.

  ## Examples

      iex> Lux.LLM.Ollama.register()
      :ok

  """
  @spec register(keyword()) :: :ok
  def register(opts \\ []) do
    models = Keyword.get(opts, :models, [@default_model, "mistral", "codellama"])

    ProviderRegistry.register(:ollama, %{
      module: __MODULE__,
      models: models,
      cost_per_1k_tokens: %{default: %{input: 0.0, output: 0.0}},  # Free!
      max_tokens: 4096,
      features: [:streaming, :local, :no_cost],
      priority: Keyword.get(opts, :priority, 4),
      enabled: true,
      host: Keyword.get(opts, :host, get_host())
    })

    :ok
  end

  # Private functions

  defp get_host do
    Application.get_env(:lux, :ollama, [])
    |> Keyword.get(:host, @default_host)
  end

  defp make_request(method, url, body, headers, timeout) do
    req = Req.new(base_url: "", receive_timeout: timeout)

    options = [headers: headers]
    options = if body, do: Keyword.put(options, :json, body), else: options

    case method do
      :get -> Req.get(req, url: url)
      :post -> Req.post(req, url: url, json: body)
      :delete -> Req.delete(req, url: url, json: body)
    end
  end

  defp handle_success_response(response_body, model) do
    case response_body do
      %{"response" => text} ->
        {:ok, %{
          text: text,
          model: model,
          total_tokens: Map.get(response_body, "eval_count", 0),
          prompt_tokens: Map.get(response_body, "prompt_eval_count", 0),
          done: Map.get(response_body, "done", true),
          context: Map.get(response_body, "context", [])
        }}

      response when is_binary(response) ->
        {:ok, %{
          text: response,
          model: model,
          done: true
        }}

      other ->
        {:ok, %{
          text: inspect(other),
          model: model,
          done: true
        }}
    end
  end
end