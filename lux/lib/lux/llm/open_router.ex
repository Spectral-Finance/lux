defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation that supports passing Beams, Prisms, and Lenses as tools.

  OpenRouter provides a unified API for accessing multiple LLM providers (OpenAI, Anthropic,
  Google, Meta, etc.) through a single OpenAI-compatible endpoint. Models are specified in
  `provider/model` format (e.g., `openai/gpt-4o-mini`, `anthropic/claude-3-opus`).

  ## Features

  - OpenAI-compatible chat completions API
  - Multi-provider model routing with fallback support
  - Cost tracking via `usage.cost` in response metadata
  - Provider ordering preferences
  - Middle-out compression transforms
  - Tool/function calling support
  - JSON response mode and structured output with json_schema

  ## Configuration

  Set the `OPENROUTER_API_KEY` environment variable or pass `api_key` in the config map.

  ## Example

      OpenRouter.call("Hello!", [], %{
        model: "openai/gpt-4o-mini",
        api_key: "sk-or-..."
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

  @endpoint "https://openrouter.ai/api/v1/chat/completions"

  defmodule Config do
    @moduledoc """
    Configuration module for OpenRouter.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            max_tokens: integer(),
            top_p: float(),
            frequency_penalty: float(),
            presence_penalty: float(),
            seed: integer(),
            json_response: boolean(),
            json_schema: map(),
            tool_choice: map(),
            transforms: list(String.t()),
            route: String.t(),
            provider: map(),
            http_referer: String.t(),
            x_title: String.t(),
            messages: [map()]
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: "openai/gpt-4o-mini",
              api_key: nil,
              temperature: 0.7,
              max_tokens: nil,
              top_p: nil,
              frequency_penalty: 0.0,
              presence_penalty: 0.0,
              seed: nil,
              json_response: true,
              json_schema: nil,
              tool_choice: nil,
              transforms: nil,
              route: nil,
              provider: nil,
              http_referer: nil,
              x_title: nil,
              messages: []
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :open_router_models)[:default],
            api_key: Application.get_env(:lux, :api_keys)[:openrouter]
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
        frequency_penalty: config.frequency_penalty,
        presence_penalty: config.presence_penalty,
        max_tokens: config.max_tokens
      }
      |> maybe_add_tools(tools_config, config.tool_choice)
      |> maybe_add_response_format(config)
      |> maybe_add_transforms(config)
      |> maybe_add_route(config)
      |> maybe_add_provider(config)

    headers =
      [
        {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
        {"Content-Type", "application/json"}
      ]
      |> maybe_add_header("HTTP-Referer", config.http_referer)
      |> maybe_add_header("X-Title", config.x_title)

    [
      url: @endpoint,
      json: body,
      headers: headers
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: 429, body: %{"error" => %{"message" => message}}}} ->
        {:error, {429, message}}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
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
    Map.put(body, :response_format, %{type: "text"})
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_map(schema) do
    Map.put(body, :response_format, %{
      type: "json_schema",
      json_schema: schema
    })
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: nil}) do
    Map.put(
      %{
        body
        | messages:
            Enum.map(body.messages, &%{&1 | content: &1.content <> "\n Reply in json format"})
      },
      :response_format,
      %{type: "json_object"}
    )
  end

  defp maybe_add_response_format(body, %Config{json_response: true, json_schema: schema})
       when is_atom(schema) do
    Map.put(body, :response_format, %{
      type: "json_schema",
      json_schema: %{name: schema.name(), schema: schema.schema()}
    })
  end

  defp maybe_add_response_format(body, _), do: Map.put(body, :response_format, %{type: "text"})

  defp maybe_add_transforms(body, %Config{transforms: nil}), do: body
  defp maybe_add_transforms(body, %Config{transforms: transforms}), do: Map.put(body, :transforms, transforms)

  defp maybe_add_route(body, %Config{route: nil}), do: body
  defp maybe_add_route(body, %Config{route: route}), do: Map.put(body, :route, route)

  defp maybe_add_provider(body, %Config{provider: nil}), do: body
  defp maybe_add_provider(body, %Config{provider: provider}), do: Map.put(body, :provider, provider)

  defp maybe_add_header(headers, _name, nil), do: headers
  defp maybe_add_header(headers, name, value), do: headers ++ [{name, value}]

  @doc """
  Converts a tool module or struct to an OpenRouter-compatible function definition.

  Supports Beams, Prisms, Lenses, and Python-based tools.
  """
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

      usage = body["usage"]

      metadata = %{
        id: body["id"],
        created: body["created"],
        usage: usage,
        system_fingerprint: body["system_fingerprint"],
        cost: get_in(usage, ["cost"])
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

  @doc """
  Parses the content string from the LLM response.

  Attempts to decode as JSON. Returns `{:ok, parsed}` on success,
  or `{:error, reason}` if the content is not valid JSON.
  """
  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} ->
        {:ok, structured_output}

      {:error, _} ->
        {:error, "failed to parse content: #{inspect(content)}"}
    end
  end

  def parse_content(_), do: {:ok, nil}

  @doc """
  Executes a list of tool calls returned by the LLM.
  """
  def execute_tool_calls(tool_calls) when is_list(tool_calls) do
    tool_calls
    |> Enum.map(&execute_tool_call/1)
    |> Enum.reduce({:ok, []}, fn
      {:ok, result, _log}, {:ok, results} ->
        {:ok, [result | results]}

      {:ok, result}, {:ok, results} ->
        {:ok, [result | results]}

      error, _ ->
        error
    end)
  end

  def execute_tool_calls(nil), do: {:ok, nil}

  @doc """
  Executes a single tool call by name and arguments.
  """
  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
    args = Jason.decode!(args)

    execute_tool(tool_name, args, nil)
  end

  @doc """
  Executes a tool by name or module reference.
  """
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
    Logger.error("OpenRouter API error: #{inspect(error)}")
    {:error, "OpenRouter API error: #{inspect(error)}"}
  end
end
