defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM provider for local model inference.

  Supports any model available in the local Ollama installation,
  including Llama 3, Mistral, CodeLlama, and custom models.

  ## Configuration

      config :lux, :ollama,
        endpoint: "http://localhost:11434",
        default_model: "llama3"

  Or via runtime config:

      config :lux, :api_keys,
        ollama: "optional_api_key"
  """

  @behaviour Lux.LLM.Provider

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @default_endpoint "http://localhost:11434"
  @default_model "llama3"

  defmodule Config do
    @moduledoc """
    Configuration for Ollama provider.
    """
    @type t :: %__MODULE__{
      endpoint: String.t(),
      model: String.t(),
      api_key: String.t() | nil,
      temperature: float(),
      max_tokens: integer() | nil,
      top_p: float(),
      top_k: integer(),
      repeat_penalty: float(),
      seed: integer() | nil,
      stream: boolean(),
      messages: [map()]
    }

    defstruct endpoint: @default_endpoint,
      model: @default_model,
      api_key: nil,
      temperature: 0.7,
      max_tokens: nil,
      top_p: 0.9,
      top_k: 40,
      repeat_penalty: 1.1,
      seed: nil,
      stream: false,
      messages: []
  end

  @impl true
  def call(prompt, tools, config) do
    config = struct(Config, Map.merge(default_config(), config))

    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    body = %{
      model: config.model,
      messages: messages,
      temperature: config.temperature,
      options: %{
        top_p: config.top_p,
        top_k: config.top_k,
        repeat_penalty: config.repeat_penalty
      },
      stream: config.stream
    }
    |> maybe_add_max_tokens(config.max_tokens)
    |> maybe_add_tools(tools_config)
    |> maybe_add_seed(config.seed)

    headers = [{"Content-Type", "application/json"}]
    |> maybe_add_auth(config.api_key)

    result =
      [
        url: "#{config.endpoint}/api/chat",
        json: body,
        headers: headers,
        receive_timeout: 120_000
      ]
      |> Req.new()
      |> Req.post()

    case result do
      {:ok, %{status: 200} = response} ->
        handle_response(response)

      {:ok, %{status: status}} ->
        {:error, "Ollama returned status #{status}"}

      {:error, error} ->
        {:error, "Ollama connection error: #{inspect(error)}"}
    end
  end

  @impl true
  def models do
    case list_local_models() do
      {:ok, models} -> models
      {:error, _} -> [@default_model]
    end
  end

  @impl true
  def estimate_cost(_model, _input_tokens, _output_tokens), do: 0.0

  @impl true
  def available? do
    endpoint = Application.get_env(:lux, :ollama, [])[:endpoint] || @default_endpoint

    case Req.get("#{endpoint}/api/tags", receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  # Private helpers

  defp default_config do
    %{
      model: Application.get_env(:lux, :ollama, [])[:default_model] || @default_model,
      endpoint: Application.get_env(:lux, :ollama, [])[:endpoint] || @default_endpoint,
      api_key: Application.get_env(:lux, :api_keys, [])[:ollama]
    }
  end

  defp build_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_messages(messages) when is_list(messages), do: messages

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp tool_to_function(%Beam{module_name: name, description: description, input_schema: input_schema}) do
    %{type: "function", function: %{name: String.replace(name, ".", "_"), description: description || "", parameters: input_schema}}
  end

  defp tool_to_function(%Prism{module_name: name, description: description, input_schema: input_schema}) do
    %{type: "function", function: %{name: String.replace(name, ".", "_"), description: description || "", parameters: input_schema}}
  end

  defp tool_to_function(%Lens{module_name: name, description: description, schema: schema}) do
    %{type: "function", function: %{name: String.replace(name, ".", "_"), description: description || "", parameters: schema}}
  end

  defp maybe_add_max_tokens(body, nil), do: body
  defp maybe_add_max_tokens(body, tokens), do: Map.put(body, :max_tokens, tokens)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  defp maybe_add_seed(body, nil), do: body
  defp maybe_add_seed(body, seed), do: Map.put(body, :seed, seed)

  defp maybe_add_auth(headers, nil), do: headers
  defp maybe_add_auth(headers, key), do: headers ++ [{"Authorization", "Bearer #{key}"}]

  defp handle_response(%{body: body}) do
    content = body["message"]["content"] || ""
    model = body["model"] || "unknown"

    {:ok, %Lux.LLM.Response{
      content: content,
      tool_calls: [],
      finish_reason: body["done"] && "stop"
    }}
  end

  defp list_local_models do
    endpoint = Application.get_env(:lux, :ollama, [])[:endpoint] || @default_endpoint

    case Req.get("#{endpoint}/api/tags", receive_timeout: 5_000) do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, Enum.map(models, & &1["name"])}

      error ->
        {:error, error}
    end
  rescue
    e -> {:error, e}
  end
end
