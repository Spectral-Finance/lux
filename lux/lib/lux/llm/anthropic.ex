defmodule Lux.LLM.Anthropic do
  @moduledoc """
  Anthropic LLM implementation that supports passing Beams, Prisms, and Lenses as tools.
  Integration with Anthropic's Claude models for high-performance inference.
  """

  
  @behaviour Lux.LLM.Provider

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

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

  # ──────────────────────────────────────
  # Lux.LLM.Provider callbacks
  # ──────────────────────────────────────

  @impl Lux.LLM.Provider
  def models do
    [
      "claude-3-opus-20240229",
      "claude-3-sonnet-20240229",
      "claude-3-haiku-20240307",
      "claude-3.5-sonnet-20241022",
      "claude-3.5-haiku-20241022",
      "claude-opus-4-20250514",
      "claude-sonnet-4-20250514"
    ]
  end

  @impl Lux.LLM.Provider
  def models(criteria) do
    supported = models()

    Enum.reduce(criteria, supported, fn
      {:capability, :vision}, acc ->
        Enum.filter(acc, &(String.contains?(&1, "opus") || String.contains?(&1, "sonnet")))

      {:capability, :tools}, acc ->
        acc

      {:max_cost, max_cost}, acc ->
        Enum.filter(acc, fn model ->
          case cost(model) do
            {:ok, %{input_per_1k_tokens: input, output_per_1k_tokens: output}} ->
              input + output <= max_cost

            _ ->
              false
          end
        end)

      _, acc ->
        acc
    end)
  end

  @impl Lux.LLM.Provider
  def cost("claude-3-opus-20240229"), do: {:ok, %{model: "claude-3-opus-20240229", input_per_1k_tokens: 0.015, output_per_1k_tokens: 0.075, currency: "USD"}}
  def cost("claude-3-sonnet-20240229"), do: {:ok, %{model: "claude-3-sonnet-20240229", input_per_1k_tokens: 0.003, output_per_1k_tokens: 0.015, currency: "USD"}}
  def cost("claude-3-haiku-20240307"), do: {:ok, %{model: "claude-3-haiku-20240307", input_per_1k_tokens: 0.00025, output_per_1k_tokens: 0.00125, currency: "USD"}}
  def cost("claude-3.5-sonnet-20241022"), do: {:ok, %{model: "claude-3.5-sonnet-20241022", input_per_1k_tokens: 0.003, output_per_1k_tokens: 0.015, currency: "USD"}}
  def cost("claude-3.5-haiku-20241022"), do: {:ok, %{model: "claude-3.5-haiku-20241022", input_per_1k_tokens: 0.0008, output_per_1k_tokens: 0.004, currency: "USD"}}
  def cost("claude-opus-4-20250514"), do: {:ok, %{model: "claude-opus-4-20250514", input_per_1k_tokens: 0.012, output_per_1k_tokens: 0.060, currency: "USD"}}
  def cost("claude-sonnet-4-20250514"), do: {:ok, %{model: "claude-sonnet-4-20250514", input_per_1k_tokens: 0.003, output_per_1k_tokens: 0.015, currency: "USD"}}
  def cost(_), do: {:error, :unknown_model}

  @impl Lux.LLM.Provider
  def capabilities do
    [:chat, :tools, :streaming, :vision, :caching]
  end

  @impl Lux.LLM.Provider
  def default_config do
    %Config{}
  end

  @impl Lux.LLM.Provider
  def metadata do
    %{
      name: "Anthropic",
      module: __MODULE__,
      description: "Anthropic Claude models for high-performance inference",
      models: models(),
      capabilities: capabilities(),
      cost_per_1k_input_tokens: 0.003,
      cost_per_1k_output_tokens: 0.015,
      priority: 2,
      enabled: true,
      tags: ["anthropic", "claude"]
    }
  end

  # ──────────────────────────────────────
  # Lux.LLM callbacks
  # ──────────────────────────────────────

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
      url: @endpoint,
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

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools_config) do
    Map.put(body, :tools, tools_config)
  end

  defp maybe_add_response_format(body, _config) do
    # Implementation for response format configuration
    body
  end

  defp handle_successful_response(response) do
    case extract_content_and_tool_calls(response.body) do
      {content, []} ->
        {:ok, %Lux.LLM.Response{
          content: content,
          tool_calls: [],
          finish_reason: response.body["stop_reason"]
        }}

      {_content, tool_calls} ->
        {:ok, %Lux.LLM.Response{
          content: nil,
          tool_calls: tool_calls,
          finish_reason: response.body["stop_reason"]
        }}
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
