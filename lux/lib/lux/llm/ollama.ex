defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation for local model support.

  Uses Ollama's OpenAI-compatible `/v1/chat/completions` endpoint,
  enabling self-hosted models (llama3, mistral, phi3, etc.) as a
  drop-in replacement for cloud LLMs.

  ## Configuration

      config :lux, Lux.LLM.Ollama,
        endpoint: "http://localhost:11434/v1/chat/completions",
        model: "llama3",
        receive_timeout: 120_000

  ## Usage

      Lux.LLM.Ollama.call("Explain quantum computing", [], %{
        model: "mistral",
        temperature: 0.7
      })
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @default_endpoint "http://localhost:11434/v1/chat/completions"

  defmodule Config do
    @moduledoc "Configuration module for Ollama."

    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            temperature: float(),
            max_tokens: integer() | nil,
            receive_timeout: integer(),
            seed: integer() | nil,
            n: integer(),
            json_response: boolean(),
            messages: [map()]
          }

    defstruct endpoint: "http://localhost:11434/v1/chat/completions",
              model: "llama3",
              temperature: 0.7,
              max_tokens: nil,
              receive_timeout: 120_000,
              seed: nil,
              n: 1,
              json_response: false,
              messages: []
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            endpoint:
              Application.get_env(:lux, __MODULE__, [])
              |> Keyword.get(:endpoint, @default_endpoint),
            model:
              Application.get_env(:lux, :ollama_models, [])
              |> Keyword.get(:default, "llama3")
          },
          config
        )
      )

    messages = config.messages ++ [%{role: "user", content: prompt}]
    tools_config = build_tools_config(tools)

    body =
      %{
        model: config.model,
        messages: messages,
        temperature: config.temperature,
        stream: false
      }
      |> maybe_add_max_tokens(config)
      |> maybe_add_seed(config)
      |> maybe_add_tools(tools_config)
      |> maybe_add_json_format(config)

    [
      url: config.endpoint,
      json: body,
      headers: [{"Content-Type", "application/json"}],
      receive_timeout: config.receive_timeout
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: status, body: %{"error" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, inspect(body)}}

      {:error, %{reason: :econnrefused}} ->
        {:error, "Ollama is not running. Start it with: ollama serve"}

      {:error, error} ->
        Logger.error("Ollama API error: #{inspect(error)}")
        {:error, "Ollama error: #{inspect(error)}"}
    end
  end

  defp maybe_add_max_tokens(body, %Config{max_tokens: nil}), do: body
  defp maybe_add_max_tokens(body, %Config{max_tokens: n}), do: Map.put(body, :num_predict, n)

  defp maybe_add_seed(body, %Config{seed: nil}), do: body
  defp maybe_add_seed(body, %Config{seed: s}), do: Map.put(body, :seed, s)

  defp maybe_add_tools(body, []), do: body

  defp maybe_add_tools(body, tools) do
    Map.put(body, :tools, tools)
  end

  defp maybe_add_json_format(body, %Config{json_response: true}) do
    Map.put(body, :format, "json")
  end

  defp maybe_add_json_format(body, _), do: body

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp handle_response(%{body: body}, _config) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message, "finish_reason" => finish_reason} <- choice,
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
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

  defp parse_content(nil), do: {:ok, nil}

  defp parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:ok, content}
    end
  end

  defp execute_tool_calls(nil), do: {:ok, nil}

  defp execute_tool_calls(tool_calls) when is_list(tool_calls) do
    tool_calls
    |> Enum.map(&execute_tool_call/1)
    |> Enum.reduce({:ok, []}, fn
      {:ok, result, _log}, {:ok, results} -> {:ok, [result | results]}
      {:ok, result}, {:ok, results} -> {:ok, [result | results]}
      error, _ -> error
    end)
  end

  defp execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
    args = Jason.decode!(args)

    tool_name
    |> String.replace("_", ".")
    |> List.wrap()
    |> Module.concat()
    |> Code.ensure_loaded()
    |> case do
      {:module, module_name} -> execute_tool(module_name, args)
      {:error, _} -> {:error, "Failed to load tool: #{tool_name}"}
    end
  end

  defp execute_tool(module, args) do
    cond do
      Lux.prism?(module) -> module.handler(args, nil)
      Lux.beam?(module) -> module.run(args, nil)
      Lux.lens?(module) -> module.focus(args)
      true -> {:error, "Unknown tool type: #{inspect(module)}"}
    end
  end

  def tool_to_function(tool_module) when is_atom(tool_module) do
    cond do
      Lux.prism?(tool_module) -> tool_to_function(tool_module.view())
      Lux.beam?(tool_module) -> tool_to_function(tool_module.view())
      Lux.lens?(tool_module) -> tool_to_function(tool_module.view())
      true -> raise "Unsupported tool type: #{inspect(tool_module)}"
    end
  end

  def tool_to_function(%Beam{module_name: name, description: desc, input_schema: schema}) do
    %{
      type: "function",
      function: %{name: String.replace(name, ".", "_"), description: desc || "", parameters: schema}
    }
  end

  def tool_to_function(%Prism{module_name: name, description: desc, input_schema: schema}) do
    %{
      type: "function",
      function: %{name: String.replace(name, ".", "_"), description: desc || "", parameters: schema}
    }
  end

  def tool_to_function(%Lens{module_name: name, description: desc, schema: schema}) do
    %{
      type: "function",
      function: %{name: String.replace(name, ".", "_"), description: desc || "", parameters: schema}
    }
  end
end
