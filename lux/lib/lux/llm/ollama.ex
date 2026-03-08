defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation for local model support.

  Ollama provides a local API compatible with OpenAI's chat completions format,
  enabling self-hosted LLM capabilities with optimized performance.

  ## Features
  - Local model management (list, pull, delete)
  - OpenAI-compatible chat completions API
  - Support for tool calling
  - Model caching and resource management
  - Performance monitoring via response metadata

  ## Configuration

  Configure Ollama in your `config/config.exs`:

      config :lux, Lux.LLM.Ollama,
        endpoint: "http://localhost:11434"

      config :lux, :ollama_models,
        default: "llama3.2"

  ## Usage

      iex> Lux.LLM.Ollama.call("Hello!", [], %{model: "llama3.2"})
      {:ok, %Lux.Signal{...}}

      iex> Lux.LLM.Ollama.list_models()
      {:ok, [%{name: "llama3.2", size: 2_000_000_000, ...}, ...]}

      iex> Lux.LLM.Ollama.pull_model("mistral")
      :ok
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.OpenAI
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @default_endpoint "http://localhost:11434"

  defmodule Config do
    @moduledoc """
    Configuration module for Ollama.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            temperature: float(),
            frequency_penalty: float(),
            receive_timeout: integer(),
            seed: integer(),
            num_ctx: integer(),
            num_predict: integer(),
            top_k: integer(),
            top_p: float(),
            repeat_penalty: float(),
            json_response: boolean(),
            json_schema: map(),
            max_tokens: integer(),
            tool_choice: map(),
            keep_alive: String.t(),
            messages: [map()]
          }

    defstruct endpoint: "http://localhost:11434",
              model: "llama3.2",
              temperature: 0.7,
              frequency_penalty: 0.0,
              receive_timeout: 120_000,
              seed: nil,
              num_ctx: nil,
              num_predict: nil,
              top_k: nil,
              top_p: nil,
              repeat_penalty: nil,
              json_response: true,
              json_schema: nil,
              max_tokens: nil,
              tool_choice: nil,
              keep_alive: "5m",
              messages: []
  end

  # ─── Chat Completions (LLM Behaviour) ────────────────────────────────────

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            endpoint:
              Application.get_env(:lux, __MODULE__, [])[:endpoint] || @default_endpoint,
            model:
              (Application.get_env(:lux, :ollama_models) || %{})[:default] || "llama3.2"
          },
          config
        )
      )

    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        stream: false,
        temperature: config.temperature,
        max_tokens: config.max_tokens
      }
      |> maybe_add_tools(tools_config, config.tool_choice)
      |> maybe_add_response_format(config)
      |> maybe_add_options(config)

    url = "#{config.endpoint}/v1/chat/completions"

    [
      url: url,
      json: body,
      headers: [{"Content-Type", "application/json"}],
      receive_timeout: config.receive_timeout
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
        {:error, {status, inspect(body)}}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error,
         "Ollama is not running. Start it with: ollama serve"}

      {:error, error} ->
        handle_error(error)
    end
  end

  # ─── Model Management ────────────────────────────────────────────────────

  @doc """
  Lists all locally available models.

  ## Examples

      iex> Lux.LLM.Ollama.list_models()
      {:ok, [%{name: "llama3.2:latest", size: 2_000_000_000, ...}]}
  """
  @spec list_models(keyword()) :: {:ok, list(map())} | {:error, term()}
  def list_models(opts \\ []) do
    endpoint = opts[:endpoint] || get_endpoint()

    [url: "#{endpoint}/api/tags"]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, models}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, "Ollama is not running. Start it with: ollama serve"}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Pulls (downloads) a model from the Ollama registry.

  ## Examples

      iex> Lux.LLM.Ollama.pull_model("mistral")
      :ok

      iex> Lux.LLM.Ollama.pull_model("llama3.2:70b")
      :ok
  """
  @spec pull_model(String.t(), keyword()) :: :ok | {:error, term()}
  def pull_model(model_name, opts \\ []) do
    endpoint = opts[:endpoint] || get_endpoint()

    [url: "#{endpoint}/api/pull", json: %{name: model_name, stream: false}, receive_timeout: 600_000]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200}} ->
        Logger.info("Ollama: model #{model_name} pulled successfully")
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Deletes a locally cached model.

  ## Examples

      iex> Lux.LLM.Ollama.delete_model("mistral")
      :ok
  """
  @spec delete_model(String.t(), keyword()) :: :ok | {:error, term()}
  def delete_model(model_name, opts \\ []) do
    endpoint = opts[:endpoint] || get_endpoint()

    [url: "#{endpoint}/api/delete", json: %{name: model_name}]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.delete()
    |> case do
      {:ok, %{status: 200}} ->
        Logger.info("Ollama: model #{model_name} deleted")
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Shows details about a model including modelfile, template, parameters, license, and system message.

  ## Examples

      iex> Lux.LLM.Ollama.show_model("llama3.2")
      {:ok, %{"modelfile" => "...", "parameters" => "...", ...}}
  """
  @spec show_model(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def show_model(model_name, opts \\ []) do
    endpoint = opts[:endpoint] || get_endpoint()

    [url: "#{endpoint}/api/show", json: %{name: model_name}]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Checks if Ollama is running and returns version information.

  ## Examples

      iex> Lux.LLM.Ollama.health_check()
      {:ok, %{"version" => "0.5.4"}}
  """
  @spec health_check(keyword()) :: {:ok, map()} | {:error, term()}
  def health_check(opts \\ []) do
    endpoint = opts[:endpoint] || get_endpoint()

    [url: "#{endpoint}/api/version"]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, "Ollama is not running"}

      {:error, error} ->
        {:error, error}
    end
  end

  # ─── Private Helpers ──────────────────────────────────────────────────────

  defp build_messages(prompt), do: [%{role: "user", content: prompt}]

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &OpenAI.tool_to_function/1)

  defp maybe_add_tools(body, [], _tool_choice), do: body

  defp maybe_add_tools(body, tools, tool_choice) do
    body
    |> Map.put(:tools, tools)
    |> Map.put(:tool_choice, format_tool_choice(tool_choice))
  end

  defp format_tool_choice(:none), do: "none"
  defp format_tool_choice(:auto), do: "auto"

  defp format_tool_choice(name) when is_binary(name),
    do: %{"type" => "function", "function" => %{"name" => String.replace(name, ".", "_")}}

  defp format_tool_choice(_), do: "auto"

  defp maybe_add_response_format(body, %Config{json_response: false}) do
    body
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: nil}) do
    Map.put(
      %{
        body
        | messages:
            Enum.map(body.messages, &%{&1 | content: &1.content <> "\n Reply in JSON format."})
      },
      :format,
      "json"
    )
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_map(schema) do
    Map.put(body, :format, schema)
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_atom(schema) do
    Map.put(body, :format, %{name: schema.name(), schema: schema.schema()})
  end

  defp maybe_add_response_format(body, _), do: body

  defp maybe_add_options(body, config) do
    options =
      %{}
      |> maybe_put(:seed, config.seed)
      |> maybe_put(:num_ctx, config.num_ctx)
      |> maybe_put(:num_predict, config.num_predict)
      |> maybe_put(:top_k, config.top_k)
      |> maybe_put(:top_p, config.top_p)
      |> maybe_put(:repeat_penalty, config.repeat_penalty)

    if map_size(options) > 0 do
      Map.put(body, :options, options)
    else
      body
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp handle_response(%{body: body}) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message, "finish_reason" => finish_reason} <- choice,
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls_results} <- OpenAI.execute_tool_calls(message["tool_calls"]) do
      payload = %{
        content: content,
        model: body["model"],
        finish_reason: finish_reason,
        tool_calls: message["tool_calls"],
        tool_calls_results: tool_calls_results
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

  defp parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} -> {:ok, structured_output}
      {:error, _} -> {:ok, content}
    end
  end

  defp parse_content(_), do: {:ok, nil}

  defp get_endpoint do
    Application.get_env(:lux, __MODULE__, [])[:endpoint] || @default_endpoint
  end

  defp handle_error(error) do
    Logger.error("Ollama API error: #{inspect(error)}")
    {:error, "Ollama API error: #{inspect(error)}"}
  end
end
