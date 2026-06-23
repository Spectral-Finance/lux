defmodule Lux.LLM.Anthropic do
  @moduledoc """
  Anthropic LLM implementation that supports passing Beams, Prisms, and Lenses as tools.
  Integration with Anthropic's Claude models for high-performance inference.
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  @endpoint "https://api.anthropic.com/v1/messages"

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

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :anthropic_models)[:default],
            api_key: Application.get_env(:lux, :api_keys)[:anthropic]
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
        max_tokens: config.max_tokens,
        system: config.system
      }
      |> maybe_add_tools(tools_config)
      |> maybe_add_response_format(config)

    [
      url: config.endpoint || @endpoint,
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
        handle_successful_response(response)

      {:ok, response} ->
        handle_error_response(response)

      {:error, error} ->
        {:error, "Error calling Anthropic API: #{inspect(error)}"}
    end
  end

  # Private functions for implementation details

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
    name = (is_binary(beam.module_name) and beam.module_name != "" and beam.module_name) || 
           (is_binary(beam.name) and beam.name != "" and beam.name) || 
           "unnamed_beam"

    %{
      name: String.replace(name, ".", "_"),
      description: beam.description || "",
      input_schema: beam.input_schema
    }
  end

  defp tool_to_function(%Prism{} = prism) do
    name = (is_binary(prism.module_name) and prism.module_name != "" and prism.module_name) || 
           (is_binary(prism.name) and prism.name != "" and prism.name) || 
           "unnamed_prism"

    %{
      name: String.replace(name, ".", "_"),
      description: prism.description || "",
      input_schema: prism.input_schema
    }
  end

  defp tool_to_function(%Lens{} = lens) do
    name = (is_binary(lens.module_name) and lens.module_name != "" and lens.module_name) || 
           (is_binary(lens.name) and lens.name != "" and lens.name) || 
           "unnamed_lens"

    %{
      name: String.replace(name, ".", "_"),
      description: lens.description || "",
      input_schema: lens.schema
    }
  end

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools_config) do
    Map.put(body, :tools, tools_config)
  end

  defp maybe_add_response_format(body, _config) do
    # Implementation for response format configuration
    body
  end

  defp handle_successful_response(response) do
    payload_base = %{
      model: response.body["model"],
      finish_reason: response.body["stop_reason"],
      tool_calls_results: []
    }
    
    metadata = %{
      id: response.body["id"],
      usage: response.body["usage"]
    }

    case extract_content_and_tool_calls(response.body) do
      {content, []} ->
        parsed_content = case Jason.decode(content) do
          {:ok, decoded} -> decoded
          _ -> %{"text" => content}
        end

        signal =
          Lux.Signal.new(%{
            schema_id: ResponseSignal,
            payload: Map.merge(payload_base, %{content: parsed_content, tool_calls: []}),
            metadata: metadata
          })
          
        ResponseSignal.validate(signal)

      {_content, tool_calls} ->
        signal =
          Lux.Signal.new(%{
            schema_id: ResponseSignal,
            payload: Map.merge(payload_base, %{content: nil, tool_calls: tool_calls}),
            metadata: metadata
          })
          
        ResponseSignal.validate(signal)
    end
  end

  defp extract_content_and_tool_calls(body) do
    content_items = body["content"] || []

    {text_content, tool_calls} =
      Enum.reduce(content_items, {"", []}, fn item, {text_acc, tools_acc} ->
        case item do
          %{"type" => "text", "text" => text} ->
            {text, tools_acc}

          %{"type" => "tool_use", "name" => name, "input" => input} ->
            tool_call = %{
              type: "function",
              name: name,
              params: input
            }

            {text_acc, [tool_call | tools_acc]}

          _ ->
            {text_acc, tools_acc}
        end
      end)

    {text_content, Enum.reverse(tool_calls)}
  end

  defp handle_error_response(response) do
    {:error, "Error calling Anthropic API: #{inspect(response.body)}"}
  end
end
