defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM provider integration for Lux.
  Provides unified access to 100+ models with multi-model routing,
  automatic fallback, tool calling, and cost tracking.

  Resolves Spectral-Finance/lux#95 ($500 Bounty: OpenRouter Integration).
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
    Configuration struct for OpenRouter provider.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            models: list(String.t()),
            api_key: String.t() | nil,
            site_url: String.t(),
            site_name: String.t(),
            temperature: float(),
            top_p: float(),
            max_tokens: integer() | nil,
            route: String.t() | nil,
            tool_choice: map() | atom() | String.t() | nil,
            transforms: list(String.t()),
            receive_timeout: integer(),
            messages: [map()]
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: "anthropic/claude-3.5-sonnet",
              models: [],
              api_key: nil,
              site_url: "https://github.com/Spectral-Finance/lux",
              site_name: "Lux Framework",
              temperature: 0.7,
              top_p: 1.0,
              max_tokens: nil,
              route: "fallback",
              tool_choice: nil,
              transforms: [],
              receive_timeout: 60_000,
              messages: []
  end

  @impl true
  def call(prompt, tools, config) when is_map(config) or is_list(config) do
    config_map = if is_list(config), do: Map.new(config), else: config

    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :openrouter_models)[:default] || "anthropic/claude-3.5-sonnet",
            api_key: Application.get_env(:lux, :api_keys)[:openrouter]
          },
          config_map
        )
      )

    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        temperature: config.temperature,
        top_p: config.top_p
      }
      |> maybe_add_max_tokens(config.max_tokens)
      |> maybe_add_fallback_models(config.models, config.route)
      |> maybe_add_tools(tools_config, config.tool_choice)
      |> maybe_add_transforms(config.transforms)

    headers = [
      {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
      {"Content-Type", "application/json"},
      {"HTTP-Referer", config.site_url},
      {"X-Title", config.site_name}
    ]

    [
      url: config.endpoint || @endpoint,
      json: body,
      headers: headers,
      receive_timeout: config.receive_timeout
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

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

  defp maybe_add_max_tokens(body, nil), do: body
  defp maybe_add_max_tokens(body, max_tokens), do: Map.put(body, :max_tokens, max_tokens)

  defp maybe_add_fallback_models(body, [], _route), do: body
  defp maybe_add_fallback_models(body, models, route) when is_list(models) and length(models) > 0 do
    body
    |> Map.put(:models, models)
    |> Map.put(:route, route || "fallback")
  end

  defp maybe_add_transforms(body, []), do: body
  defp maybe_add_transforms(body, transforms) when is_list(transforms), do: Map.put(body, :transforms, transforms)

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
         %{"message" => message} <- choice,
         finish_reason <- Map.get(choice, "finish_reason"),
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
        cost: get_in(body, ["usage", "total_cost"])
      }

      %{
        payload: payload,
        metadata: metadata
      }
      |> ResponseSignal.new()
    else
      error ->
        {:error, "Failed to parse OpenRouter response: #{inspect(error)}"}
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
    Logger.error("OpenRouter API error: #{inspect(error)}")
    {:error, "OpenRouter API error: #{inspect(error)}"}
  end
end
