defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama local model provider integration for Lux.
  Provides self-hosted, offline LLM execution, model lifecycle management (list/pull),
  resource controls (keep_alive, num_ctx), and tool calling.

  Resolves Spectral-Finance/lux#96 ($400 Bounty: Local Model Support via Ollama).
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @default_endpoint "http://localhost:11434"

  defmodule Config do
    @moduledoc """
    Configuration struct for Ollama local provider.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            temperature: float(),
            top_p: float(),
            num_ctx: integer() | nil,
            keep_alive: String.t() | integer() | nil,
            json_response: boolean(),
            receive_timeout: integer(),
            messages: [map()]
          }

    defstruct endpoint: "http://localhost:11434",
              model: "llama3.2",
              temperature: 0.7,
              top_p: 0.9,
              num_ctx: 4096,
              keep_alive: "5m",
              json_response: false,
              receive_timeout: 120_000,
              messages: []
  end

  @doc """
  Lists models currently installed and cached in the local Ollama daemon.
  """
  def list_models(endpoint \\\\ @default_endpoint) do
    url = "#{endpoint}/api/tags"

    Req.get(url: url)
    |> case do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, models}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, "Failed to connect to local Ollama at #{url}: #{inspect(error)}"}
    end
  end

  @doc """
  Pulls and caches a model in the local Ollama daemon.
  """
  def pull_model(model_name, endpoint \\\\ @default_endpoint) do
    url = "#{endpoint}/api/pull"

    Req.post(url: url, json: %{"name" => model_name, "stream" => false}, receive_timeout: 300_000)
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, "Failed to pull model #{model_name}: #{inspect(error)}"}
    end
  end

  @impl true
  def call(prompt, tools, config) when is_map(config) or is_list(config) do
    config_map = if is_list(config), do: Map.new(config), else: config

    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :ollama_models)[:default] || "llama3.2",
            endpoint: Application.get_env(:lux, :ollama_endpoint) || @default_endpoint
          },
          config_map
        )
      )

    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    options =
      %{
        temperature: config.temperature,
        top_p: config.top_p
      }
      |> maybe_add_num_ctx(config.num_ctx)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        stream: false,
        options: options
      }
      |> maybe_add_keep_alive(config.keep_alive)
      |> maybe_add_format(config.json_response)
      |> maybe_add_tools(tools_config)

    endpoint_base = config.endpoint || @default_endpoint
    chat_url = "#{endpoint_base}/api/chat"

    [
      url: chat_url,
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

      {:ok, %{status: 404, body: %{"error" => message}}} ->
        {:error, {:model_not_found, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, %{reason: :econnrefused}} ->
        {:error, "Ollama daemon offline or unreachable at #{endpoint_base}"}

      {:error, error} ->
        handle_error(error)
    end
  end

  defp build_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_messages(messages) when is_list(messages), do: messages

  defp build_tools_config([]), do: []
  defp build_tools_config(tools) when is_list(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_num_ctx(options, nil), do: options
  defp maybe_add_num_ctx(options, num_ctx), do: Map.put(options, :num_ctx, num_ctx)

  defp maybe_add_keep_alive(body, nil), do: body
  defp maybe_add_keep_alive(body, keep_alive), do: Map.put(body, :keep_alive, keep_alive)

  defp maybe_add_format(body, true), do: Map.put(body, :format, "json")
  defp maybe_add_format(body, _), do: body

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
    with %{"message" => message} <- body,
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
      payload = %{
        content: content,
        model: body["model"],
        done: body["done"],
        tool_calls: message["tool_calls"],
        tool_calls_results: tool_calls_results
      }

      metadata = %{
        total_duration: body["total_duration"],
        load_duration: body["load_duration"],
        prompt_eval_count: body["prompt_eval_count"],
        eval_count: body["eval_count"]
      }

      %{
        payload: payload,
        metadata: metadata
      }
      |> ResponseSignal.new()
    else
      error ->
        {:error, "Failed to parse Ollama response: #{inspect(error)}"}
    end
  end

  def parse_content(content) when is_binary(content), do: {:ok, content}
  def parse_content(nil), do: {:ok, nil}
  def parse_content(other), do: {:ok, inspect(other)}

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

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) when is_binary(args) do
    decoded_args = case Jason.decode(args) do
      {:ok, parsed} -> parsed
      _ -> %{}
    end
    execute_tool(tool_name, decoded_args, nil)
  end

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) when is_map(args) do
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
        {:error, "Tool #{tool_module} is not a valid Beam or Prism"}
    end
  end

  defp handle_error(error) do
    Logger.error("Ollama API error: #{inspect(error)}")
    {:error, "Ollama API error: #{inspect(error)}"}
  end
end
