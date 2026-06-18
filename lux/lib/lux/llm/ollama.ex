defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama local LLM implementation. Connects to a local Ollama instance
  using the `/api/chat` endpoint. No API key required since Ollama runs locally.
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @endpoint "http://localhost:11434/api/chat"

  defmodule Config do
    @moduledoc """
    Configuration module for Ollama.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            temperature: float(),
            stream: boolean(),
            receive_timeout: integer(),
            messages: [map()]
          }

    defstruct endpoint: "http://localhost:11434/api/chat",
              model: "llama3.2",
              temperature: 0.7,
              stream: false,
              receive_timeout: 60_000,
              messages: []
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :ollama_models)[:default]
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
        temperature: config.temperature,
        stream: config.stream
      }
      |> maybe_add_tools(tools_config)

    [
      url: Lux.Config.resolve(config.endpoint),
      json: body,
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: status, body: %{"error" => error}}} ->
        {:error, {status, error}}

      {:error, %{reason: :econnrefused}} ->
        {:error, :connection_refused}

      {:error, %{reason: :timeout}} ->
        {:error, :timeout}

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

  def tool_to_function(%Beam{module_name: name, description: description, input_schema: input_schema}) do
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

  def tool_to_function(%Lens{module_name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: schema
      }
    }
  end

  defp handle_response(%{body: body}, _config) do
    %{"message" => message} = body

    {:ok, content} = parse_content(message["content"])
    {:ok, tool_calls_results} = execute_tool_calls(message["tool_calls"])

    payload = %{
      content: content,
      model: body["model"],
      finish_reason: Map.get(body, "done_reason", "stop"),
      tool_calls: message["tool_calls"],
      tool_calls_results: tool_calls_results
    }

    metadata = %{
      model: body["model"],
      created_at: body["created_at"],
      total_duration: body["total_duration"],
      prompt_eval_count: body["prompt_eval_count"],
      eval_count: body["eval_count"]
    }

    %{
      schema_id: ResponseSignal,
      payload: payload,
      metadata: metadata
    }
    |> Lux.Signal.new()
    |> ResponseSignal.validate()
  end

  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} -> {:ok, structured_output}
      {:error, _} -> {:error, "failed to parse content: #{inspect(content)}"}
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

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}})
      when is_map(args) do
    execute_tool(tool_name, args, nil)
  end

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
    args = Jason.decode!(args)
    execute_tool(tool_name, args, nil)
  end

  def execute_tool(tool_name, args, ctx \\ nil)

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
        {:error,
         "Failed to load tool module #{tool_name}: It doesn't seems to be implemented or reacheable"}

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

      Lux.lens?(tool_module) ->
        tool_module.focus(args)

      true ->
        {:error,
         """
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
