defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation for local self-hosted models. Supports standard OpenAI-compatible completions.
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
    @moduledoc """
    Configuration module for Ollama.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            temperature: float(),
            top_p: float(),
            max_tokens: integer() | nil,
            messages: [map()]
          }

    defstruct endpoint: "http://localhost:11434/v1/chat/completions",
              model: "llama3",
              temperature: 0.7,
              top_p: 0.9,
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
            model: Application.get_env(:lux, :ollama_models)[:default] || "llama3",
            endpoint: Application.get_env(:lux, :ollama)[:endpoint] || @default_endpoint
          },
          config
        )
      )

    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    body =
      %{
        model: config.model,
        messages: messages,
        temperature: config.temperature,
        top_p: config.top_p,
        max_tokens: config.max_tokens
      }
      |> maybe_add_tools(tools_config)

    [
      url: config.endpoint,
      json: body,
      headers: [
        {"Content-Type", "application/json"}
      ]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: status, body: %{"error" => message}}} ->
        {:error, {status, message}}

      {:error, error} ->
        handle_error(error)
    end
  end

  defp build_messages(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  def tool_to_function({:python, path}) do
    path
    |> Prism.view()
    |> tool_to_function()
  end

  def tool_to_function(tool_module) when is_atom(tool_module) and not is_nil(tool_module) do
    cond do
      Lux.prism?(tool_module) ->
        tool_to_function(tool_module.view())

      Lux.beam?(tool_module) ->
        tool_to_function(tool_module.view())

      Lux.lens?(tool_module) ->
        tool_to_function(tool_module.view())

      true ->
        raise "Unsupported tool type: #{inspect(tool_module)}"
    end
  end

  def tool_to_function(%Beam{name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_function(%Prism{module_name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_function(%Lens{name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: name || "unnamed_lens",
        description: description || "",
        parameters: schema
      }
    }
  end

  defp handle_response(%{body: body}, _config) do
    # Handle both OpenAI-compatible format and raw Ollama format
    cond do
      Map.has_key?(body, "choices") ->
        with %{"choices" => [choice | _]} <- body,
             %{"message" => message} <- choice,
             {:ok, content} <- parse_content(message["content"]),
             {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
          payload = %{
            content: content,
            model: body["model"],
            finish_reason: choice["finish_reason"],
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

      Map.has_key?(body, "message") ->
        with %{"message" => message} <- body,
             {:ok, content} <- parse_content(message["content"]) do
          payload = %{
            content: content,
            model: body["model"],
            finish_reason: "stop",
            tool_calls: nil,
            tool_calls_results: nil
          }

          metadata = %{
            id: nil,
            created: body["created_at"],
            usage: nil,
            system_fingerprint: nil
          }

          %{
            schema_id: ResponseSignal,
            payload: payload,
            metadata: metadata
          }
          |> Lux.Signal.new()
          |> ResponseSignal.validate()
        end

      true ->
        {:error, "Unsupported response format from Ollama: #{inspect(body)}"}
    end
  end

  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} -> {:ok, structured_output}
      {:error, _} -> {:ok, content}
    end
  end

  def parse_content(_), do: {:ok, nil}

  def execute_tool_calls(tool_calls) when is_list(tool_calls) do
    tool_calls
    |> Enum.map(&execute_tool_call/1)
    |> Enum.reduce({:ok, []}, fn
      {:ok, result, _log}, {:ok, results} -> {:ok, [result | results]}
      {:ok, result}, {:ok, results} -> {:ok, [result | results]}
      error, _ -> error
    end)
  end

  def execute_tool_calls(nil), do: {:ok, nil}

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
    args = Jason.decode!(args)
    execute_tool(tool_name, args, nil)
  end

  def execute_tool(tool_name, args, ctx) when is_binary(tool_name) do
    tool_name
    |> String.replace("_", ".")
    |> List.wrap()
    |> Module.concat()
    |> Code.ensure_loaded()
    |> case do
      {:module, module_name} ->
        execute_tool(module_name, args, ctx)

      {:error, :nofile} ->
        {:error, "Failed to load tool module #{tool_name}: It doesn't seems to be implemented or reacheable"}

      {:error, error} ->
        {:error, "Failed to load tool module #{tool_name}: #{inspect(error)}"}
    end
  end

  def execute_tool(tool_module, args, ctx) when is_atom(tool_module) do
    cond do
      Lux.prism?(tool_module) ->
        tool_module.handler(args, ctx)

      Lux.beam?(tool_module) ->
        tool_module.run(args, ctx)

      true ->
        {:error, """
        Tool #{tool_module} does not seem to be a valid Beam or Prism
        as it does not have a registered `handler` or `run` function.
        """}
    end
  end

  defp handle_error(error) do
    Logger.error("Ollama API error: #{inspect(error)}")
    {:error, "Ollama API error: #{inspect(error)}"}
  end
end
