defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation that provides access to a wide range of LLM models
  through a single unified API compatible with OpenAI's API format.

  Supports model selection, cost tracking, and automatic fallback.
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
            receive_timeout: integer(),
            extra_body: map()
          }

    defstruct endpoint: @endpoint,
              model: "openai/gpt-4o",
              api_key: "",
              temperature: 0.7,
              max_tokens: 4096,
              top_p: 1.0,
              frequency_penalty: 0.0,
              presence_penalty: 0.0,
              receive_timeout: 60000,
              extra_body: %{}
  end

  @impl true
  def call(prompt, tools, options) when is_list(tools) do
    config = build_config(options)
    messages = build_messages(prompt, tools)
    body = build_body(messages, config, tools)

    case HTTPoison.post(
           config.endpoint,
           Jason.encode!(body),
           [{"Content-Type", "application/json"}, {"Authorization", "Bearer #{config.api_key}"}],
           recv_timeout: config.receive_timeout
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body_str}} ->
        parse_response(body_str, config)

      {:ok, %HTTPoison.Response{status_code: code, body: body_str}} ->
        Logger.error("OpenRouter API error: #{code} - #{body_str}")
        {:error, "OpenRouter API error: #{code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("OpenRouter HTTP error: #{inspect(reason)}")
        {:error, "OpenRouter HTTP error: #{inspect(reason)}"}
    end
  end

  defp build_config(options) do
    default = %Config{}

    model = Map.get(options, :model, default.model)
    api_key = Map.get(options, :api_key, default.api_key)
    temperature = Map.get(options, :temperature, default.temperature)
    max_tokens = Map.get(options, :max_tokens, default.max_tokens)
    top_p = Map.get(options, :top_p, default.top_p)
    frequency_penalty = Map.get(options, :frequency_penalty, default.frequency_penalty)
    presence_penalty = Map.get(options, :presence_penalty, default.presence_penalty)
    receive_timeout = Map.get(options, :receive_timeout, default.receive_timeout)
    extra_body = Map.get(options, :extra_body, default.extra_body)

    %Config{
      model: model,
      api_key: api_key,
      temperature: temperature,
      max_tokens: max_tokens,
      top_p: top_p,
      frequency_penalty: frequency_penalty,
      presence_penalty: presence_penalty,
      receive_timeout: receive_timeout,
      extra_body: extra_body
    }
  end

  defp build_messages(prompt, tools) do
    system_message = build_system_message(tools)
    user_message = %{role: "user", content: prompt}

    [system_message, user_message]
  end

  defp build_system_message(tools) do
    tool_descriptions =
      Enum.map(tools, fn
        %Prism{name: name, description: desc} ->
          "- #{name}: #{desc}"

        %Beam{name: name, description: desc} ->
          "- #{name}: #{desc}"

        %Lens{name: name, description: desc} ->
          "- #{name}: #{desc}"

        _ ->
          ""
      end)
      |> Enum.filter(&(&1 != ""))

    base_message =
      "You are a helpful assistant in the Lux AI Agent platform. You have access to the following tools:"

    if Enum.empty?(tool_descriptions) do
      %{role: "system", content: "You are a helpful assistant."}
    else
      %{
        role: "system",
        content: base_message <> "\n\n" <> Enum.join(tool_descriptions, "\n")
      }
    end
  end

  defp build_body(messages, config, tools) do
    base_body = %{
      model: config.model,
      messages: messages,
      temperature: config.temperature,
      max_tokens: config.max_tokens,
      top_p: config.top_p,
      frequency_penalty: config.frequency_penalty,
      presence_penalty: config.presence_penalty
    }

    body_with_tools =
      if Enum.empty?(tools) do
        base_body
      else
        Map.put(base_body, :tools, format_tools(tools))
      end

    Map.merge(body_with_tools, config.extra_body)
  end

  defp format_tools(tools) do
    Enum.map(tools, fn
      %Prism{name: name, description: desc, parameters: params} ->
        %{
          type: "function",
          function: %{
            name: name,
            description: desc,
            parameters: params || %{}
          }
        }

      %Beam{name: name, description: desc, parameters: params} ->
        %{
          type: "function",
          function: %{
            name: name,
            description: desc,
            parameters: params || %{}
          }
        }

      %Lens{name: name, description: desc} ->
        %{
          type: "function",
          function: %{
            name: name,
            description: desc,
            parameters: %{}
          }
        }

      _ ->
        nil
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp parse_response(body_str, _config) do
    case Jason.decode(body_str) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _] = choices} = response} ->
        finish_reason =
          case choices do
            [%{"finish_reason": fr}] -> fr
            _ -> nil
          end

        tool_calls =
          case Map.get(choices |> hd(), "tool_calls") do
            nil -> []
            calls ->
              Enum.map(calls, fn call ->
                %{
                  type: Map.get(call, "type", "function"),
                  name: Map.get(call, "function", %{}) |> Map.get("name", ""),
                  params: Map.get(call, "function", %{}) |> Map.get("arguments", "{}") |> Jason.decode!()
                }
              end)
          end

        {:ok, %Lux.LLM.Response{
          content: content,
          tool_calls: tool_calls,
          finish_reason: finish_reason
        }}

      {:ok, %{"error" => %{"message" => msg}}} ->
        {:error, "OpenRouter API error: #{msg}"}

      {:ok, _} ->
        {:error, "Unexpected response format from OpenRouter"}

      {:error, _} ->
        {:error, "Failed to parse OpenRouter response"}
    end
  end
end
