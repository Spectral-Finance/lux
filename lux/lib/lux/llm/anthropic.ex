defmodule Lux.LLM.Anthropic do
  @moduledoc """
  Anthropic LLM implementation that supports passing Beams, Prisms, and Lenses as tools.
  Integration with Anthropic's Claude models for high-performance inference.
  """

  @behaviour Lux.LLM.Provider

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ModelConfig
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @endpoint "https://api.anthropic.com/v1/messages"

  @impl Lux.LLM.Provider
  def id, do: :anthropic

  @impl Lux.LLM.Provider
  def models do
    [
      %ModelConfig{
        id: "claude-3-5-sonnet-20241022",
        name: "Claude 3.5 Sonnet",
        provider_id: :anthropic,
        cost_per_1k_prompt_tokens: 0.003,
        cost_per_1k_completion_tokens: 0.015,
        capabilities: [:tools, :json_schema, :vision],
        context_window: 200_000
      },
      %ModelConfig{
        id: "claude-3-opus-20240229",
        name: "Claude 3 Opus",
        provider_id: :anthropic,
        cost_per_1k_prompt_tokens: 0.015,
        cost_per_1k_completion_tokens: 0.075,
        capabilities: [:tools, :json_schema, :vision],
        context_window: 200_000
      },
      %ModelConfig{
        id: "claude-3-haiku-20240307",
        name: "Claude 3 Haiku",
        provider_id: :anthropic,
        cost_per_1k_prompt_tokens: 0.00025,
        cost_per_1k_completion_tokens: 0.00125,
        capabilities: [:tools, :json_schema, :vision],
        context_window: 200_000
      }
    ]
  end

  defmodule Config do
    @moduledoc """
    Configuration module for Anthropic.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            max_tokens: integer(),
            top_p: float(),
            top_k: integer(),
            receive_timeout: integer(),
            system: String.t(),
            user: String.t(),
            messages: [map()],
            token_cache_enabled: boolean(),
            load_balancing_enabled: boolean()
          }

    defstruct endpoint: "https://api.anthropic.com/v1/messages",
              model: "claude-3-opus-20240229",
              api_key: nil,
              temperature: 0.7,
              max_tokens: 4096,
              top_p: 0.7,
              top_k: 40,
              receive_timeout: 60_000,
              system: nil,
              user: nil,
              messages: [],
              token_cache_enabled: true,
              load_balancing_enabled: true
  end

  @impl Lux.LLM.Provider
  def call(prompt, tools, config) do
    opts_map =
      cond do
        is_struct(config) -> Map.from_struct(config)
        is_map(config) -> config
        is_list(config) -> Enum.into(config, %{})
        true -> %{}
      end

    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :anthropic_models)[:default] || "claude-3-opus-20240229",
            api_key: Application.get_env(:lux, :api_keys)[:anthropic]
          },
          opts_map
        )
      )

    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        temperature: config.temperature,
        max_tokens: config.max_tokens,
        system: config.system
      }
      |> maybe_add_tools(tools_config)
      |> maybe_add_response_format(config)

    [
      url: Lux.Config.resolve(config.endpoint || @endpoint),
      json: body,
      headers: [
        {"x-api-key", Lux.Config.resolve(config.api_key)},
        {"anthropic-version", "2023-06-01"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_successful_response(response, config)

      {:ok, response} ->
        handle_error_response(response)

      {:error, error} ->
        {:error, "Error calling Anthropic API: #{inspect(error)}"}
    end
  end

  defp build_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_messages(messages) when is_list(messages) do
    messages
    |> Enum.map(fn
      %{role: role, content: _content} = message when role in ["user", "assistant", "system"] ->
        message

      message when is_binary(message) ->
        %{role: "user", content: message}
    end)
  end

  defp build_tools_config([]), do: []

  defp build_tools_config(tools) when is_list(tools) do
    tools
    |> Enum.map(&tool_to_function/1)
  end

  defp tool_to_function(%Beam{} = beam) do
    %{
      name: beam.name,
      description: beam.description,
      input_schema: beam.input_schema
    }
  end

  defp tool_to_function(%Prism{} = prism) do
    %{
      name: prism.name,
      description: prism.description,
      input_schema: prism.input_schema
    }
  end

  defp tool_to_function(%Lens{} = lens) do
    %{
      name: lens.name,
      description: lens.description,
      input_schema: lens.params
    }
  end

  defp tool_to_function(tool_module) when is_atom(tool_module) and not is_nil(tool_module) do
    cond do
      Lux.prism?(tool_module) -> tool_to_function(tool_module.view())
      Lux.beam?(tool_module) -> tool_to_function(tool_module.view())
      Lux.lens?(tool_module) -> tool_to_function(tool_module.view())
      true -> raise "Unsupported tool type: #{inspect(tool_module)}"
    end
  end

  defp maybe_add_tools(body, []), do: body

  defp maybe_add_tools(body, tools_config) do
    Map.put(body, :tools, tools_config)
  end

  defp maybe_add_response_format(body, _config), do: body

  defp handle_successful_response(response, config) do
    {text_content, tool_calls} = extract_content_and_tool_calls(response.body)

    content =
      case parse_content(text_content) do
        {:ok, parsed} -> parsed
        _ -> %{"text" => text_content}
      end

    tool_calls_results =
      case execute_tool_calls(tool_calls) do
        {:ok, results} -> results
        _ -> nil
      end

    payload = %{
      content: content,
      model: config.model,
      finish_reason: response.body["stop_reason"],
      tool_calls: tool_calls,
      tool_calls_results: tool_calls_results
    }

    metadata = %{
      id: response.body["id"],
      provider: :anthropic,
      model: config.model,
      usage: response.body["usage"]
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
      {:ok, structured_output} when is_map(structured_output) -> {:ok, structured_output}
      {:error, _} -> {:ok, %{"text" => content}}
    end
  end

  def parse_content(nil), do: {:ok, nil}
  def parse_content(other), do: {:ok, other}

  defp extract_content_and_tool_calls(body) do
    content_items = body["content"] || []

    {text_content, tool_calls} =
      Enum.reduce(content_items, {"", []}, fn item, {text_acc, tools_acc} ->
        case item do
          %{"type" => "text", "text" => text} ->
            {text_acc <> text, tools_acc}

          %{"type" => "tool_use", "name" => name, "input" => input} ->
            tool_call = %{
              "id" => "call_" <> name,
              "type" => "function",
              "function" => %{
                "name" => name,
                "arguments" => input
              }
            }

            {text_acc, [tool_call | tools_acc]}

          _ ->
            {text_acc, tools_acc}
        end
      end)

    {text_content, Enum.reverse(tool_calls)}
  end

  def execute_tool_calls(tool_calls) when is_list(tool_calls) and tool_calls != [] do
    tool_calls
    |> Enum.map(&execute_tool_call/1)
    |> Enum.reduce({:ok, []}, fn
      {:ok, result, _log}, {:ok, results} -> {:ok, [result | results]}
      {:ok, result}, {:ok, results} -> {:ok, [result | results]}
      error, _ -> error
    end)
  end

  def execute_tool_calls(_), do: {:ok, nil}

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) when is_map(args) do
    execute_tool(tool_name, args, nil)
  end

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) when is_binary(args) do
    case Jason.decode(args) do
      {:ok, decoded_args} -> execute_tool(tool_name, decoded_args, nil)
      {:error, _} -> execute_tool(tool_name, args, nil)
    end
  end

  def execute_tool(tool_name, args, ctx \\ nil)

  def execute_tool(tool_name, args, ctx) when is_binary(tool_name) do
    tool_name
    |> String.replace("_", ".")
    |> List.wrap()
    |> Module.concat()
    |> Code.ensure_loaded()
    |> case do
      {:module, module_name} -> execute_tool(module_name, args, ctx)
      {:error, _} -> {:error, "Failed to load tool module #{tool_name}"}
    end
  end

  def execute_tool(tool_module, args, ctx) when is_atom(tool_module) do
    cond do
      Lux.prism?(tool_module) -> tool_module.handler(args, ctx)
      Lux.beam?(tool_module) -> tool_module.run(args, ctx)
      Lux.lens?(tool_module) -> tool_module.focus(args)
      true -> {:error, "Tool #{tool_module} is not a valid Beam, Prism or Lens"}
    end
  end

  defp handle_error_response(response) do
    {:error, "Error calling Anthropic API: #{inspect(response.body)}"}
  end
end
