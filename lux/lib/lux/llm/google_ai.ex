defmodule Lux.LLM.GoogleAI do
  @moduledoc """
  Google AI (Gemini) LLM provider implementation.

  Supports Gemini Pro, Gemini Ultra, and Gemini 1.5 models
  with function calling, structured output, and safety settings.

  ## Configuration

      config :lux, :google_ai_models,
        default: "gemini-pro",
        available: ["gemini-pro", "gemini-ultra", "gemini-1.5-pro"]

      config :lux, :api_keys,
        google: "YOUR_GOOGLE_API_KEY"
  """

  @behaviour Lux.LLM.Provider

  require Logger

  @default_endpoint "https://generativelanguage.googleapis.com/v1beta"
  @default_model "gemini-pro"

  defmodule Config do
    @moduledoc """
    Configuration for Google AI provider.
    """
    @type t :: %__MODULE__{
      endpoint: String.t(),
      model: String.t(),
      api_key: String.t(),
      temperature: float(),
      max_tokens: integer(),
      top_p: float(),
      top_k: integer(),
      safety_settings: [map()],
      response_mime_type: String.t() | nil,
      messages: [map()]
    }

    defstruct endpoint: @default_endpoint,
      model: @default_model,
      api_key: nil,
      temperature: 0.7,
      max_tokens: 2048,
      top_p: 0.95,
      top_k: 40,
      safety_settings: [],
      response_mime_type: nil,
      messages: []
  end

  @impl true
  def call(prompt, tools, config) do
    config = struct(Config, Map.merge(default_config(), config))

    contents = config.messages ++ build_contents(prompt)
    tools_config = build_tools_config(tools)

    body = %{
      contents: contents,
      generationConfig: %{
        temperature: config.temperature,
        maxOutputTokens: config.max_tokens,
        topP: config.top_p,
        topK: config.top_k
      }
    }
    |> maybe_add_tools(tools_config)
    |> maybe_add_safety_settings(config.safety_settings)
    |> maybe_add_response_format(config.response_mime_type)

    url = "#{config.endpoint}/models/#{config.model}:generateContent?key=#{config.api_key}"

    result =
      [
        url: url,
        json: body,
        headers: [{"Content-Type", "application/json"}],
        receive_timeout: 60_000
      ]
      |> Req.new()
      |> Req.post()

    case result do
      {:ok, %{status: 200} = response} ->
        handle_response(response)

      {:ok, %{status: status, body: body}} ->
        error_msg = body["error"]["message"] || "Google AI returned status #{status}"
        {:error, error_msg}

      {:error, error} ->
        {:error, "Google AI connection error: #{inspect(error)}"}
    end
  end

  @impl true
  def models do
    Application.get_env(:lux, :google_ai_models, [])[:available] ||
      ["gemini-pro", "gemini-ultra", "gemini-1.5-pro", "gemini-1.5-flash"]
  end

  @impl true
  def estimate_cost(model, input_tokens, output_tokens) do
    costs = %{
      "gemini-pro"       => %{input: 0.00000125, output: 0.000005},
      "gemini-ultra"     => %{input: 0.000035, output: 0.000105},
      "gemini-1.5-pro"   => %{input: 0.0000035, output: 0.0000105},
      "gemini-1.5-flash" => %{input: 0.000000075, output: 0.0000003}
    }

    c = Map.get(costs, model, %{input: 0.000001, output: 0.000003})
    Float.round(input_tokens * c.input + output_tokens * c.output, 6)
  end

  @impl true
  def available? do
    api_key = Application.get_env(:lux, :api_keys, [])[:google]
    api_key != nil and api_key != ""
  end

  # Private helpers

  defp default_config do
    %{
      model: Application.get_env(:lux, :google_ai_models, [])[:default] || @default_model,
      api_key: Application.get_env(:lux, :api_keys, [])[:google],
      endpoint: @default_endpoint
    }
  end

  defp build_contents(prompt) when is_binary(prompt) do
    [%{role: "user", parts: [%{text: prompt}]}]
  end

  defp build_contents(messages) when is_list(messages) do
    Enum.map(messages, fn
      %{role: "user", content: content} ->
        %{role: "user", parts: [%{text: content}]}
      %{role: "assistant", content: content} ->
        %{role: "model", parts: [%{text: content}]}
      %{role: "system", content: content} ->
        %{role: "user", parts: [%{text: "System: #{content}"}]}
      text when is_binary(text) ->
        %{role: "user", parts: [%{text: text}]}
    end)
  end

  defp build_tools_config([]), do: []
  defp build_tools_config(tools) do
    [%{function_declarations: Enum.map(tools, &tool_to_declaration/1)}]
  end

  defp tool_to_declaration(%Lux.Prism{module_name: name, description: description, input_schema: input_schema}) do
    %{name: String.replace(name, ".", "_"), description: description || "", parameters: convert_schema(input_schema)}
  end

  defp tool_to_declaration(%Lux.Beam{module_name: name, description: description, input_schema: input_schema}) do
    %{name: String.replace(name, ".", "_"), description: description || "", parameters: convert_schema(input_schema)}
  end

  defp tool_to_declaration(%Lux.Lens{module_name: name, description: description, schema: schema}) do
    %{name: String.replace(name, ".", "_"), description: description || "", parameters: convert_schema(schema)}
  end

  # Convert JSON Schema to Gemini's OpenAPI 3.0 format
  defp convert_schema(%{type: :object, properties: props} = schema) do
    %{
      type: "OBJECT",
      properties: Map.new(props, fn {k, v} -> {Atom.to_string(k), convert_schema(v)} end),
      required: Map.get(schema, :required, [])
    }
  end

  defp convert_schema(%{type: :string}), do: %{type: "STRING"}
  defp convert_schema(%{type: :integer}), do: %{type: "INTEGER"}
  defp convert_schema(%{type: :number}), do: %{type: "NUMBER"}
  defp convert_schema(%{type: :boolean}), do: %{type: "BOOLEAN"}
  defp convert_schema(%{type: :array, items: items}), do: %{type: "ARRAY", items: convert_schema(items)}
  defp convert_schema(_), do: %{type: "STRING"}

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  defp maybe_add_safety_settings(body, []), do: body
  defp maybe_add_safety_settings(body, settings), do: Map.put(body, :safetySettings, settings)

  defp maybe_add_response_format(body, nil), do: body
  defp maybe_add_response_format(body, mime_type) do
    put_in(body, [:generationConfig, :responseMimeType], mime_type)
  end

  defp handle_response(%{body: body}) do
    case body do
      %{"candidates" => [%{"content" => %{"parts" => parts}, "finishReason" => finish_reason} | _]} ->
        content = parts
        |> Enum.map(& &1["text"])
        |> Enum.join("")

        {:ok, %Lux.LLM.Response{
          content: content,
          tool_calls: extract_tool_calls(parts),
          finish_reason: finish_reason
        }}

      %{"error" => %{"message" => message}} ->
        {:error, message}

      _ ->
        {:error, "Unexpected Google AI response format"}
    end
  end

  defp extract_tool_calls(parts) do
    parts
    |> Enum.filter(&Map.has_key?(&1, "functionCall"))
    |> Enum.map(fn %{"functionCall" => %{"name" => name, "args" => args}} ->
      %{type: "function", name: name, params: args}
    end)
  end
end
