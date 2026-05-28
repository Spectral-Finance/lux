defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation for multi-provider model routing.

  OpenRouter provides a unified API to 200+ models from OpenAI, Anthropic,
  Google, Meta, Mistral, and others — with automatic fallbacks, cost routing,
  and a single API key.

  Uses the OpenAI-compatible chat completions API with OpenRouter's base URL.

  ## Configuration

      config :lux, :api_keys, openrouter: System.get_env("OPENROUTER_API_KEY")
      config :lux, :openrouter_models, default: "openai/gpt-4o"

  ## Usage

      Lux.LLM.OpenRouter.call("Explain MCP", [], %{
        model: "anthropic/claude-3-5-sonnet",
        temperature: 0.7
      })

  ## Popular Models

  - `"openai/gpt-4o"` — OpenAI GPT-4o
  - `"anthropic/claude-3-5-sonnet"` — Claude 3.5 Sonnet
  - `"google/gemini-pro-1.5"` — Gemini Pro 1.5
  - `"meta-llama/llama-3-70b-instruct"` — Llama 3 70B
  - `"mistralai/mixtral-8x7b"` — Mixtral 8x7B
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
  @app_url "https://github.com/Spectral-Finance/lux"
  @app_name "Lux"

  defmodule Config do
    @moduledoc "Configuration module for OpenRouter."

    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t() | nil,
            temperature: float(),
            max_tokens: integer() | nil,
            receive_timeout: integer(),
            seed: integer() | nil,
            n: integer(),
            json_response: boolean(),
            json_schema: map() | nil,
            tool_choice: atom() | String.t() | nil,
            site_url: String.t() | nil,
            site_name: String.t() | nil,
            messages: [map()]
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: "openai/gpt-4o",
              api_key: nil,
              temperature: 0.7,
              max_tokens: nil,
              receive_timeout: 60_000,
              seed: nil,
              n: 1,
              json_response: true,
              json_schema: nil,
              tool_choice: nil,
              site_url: nil,
              site_name: nil,
              messages: []
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :openrouter_models, []) |> Keyword.get(:default, "openai/gpt-4o"),
            api_key: Application.get_env(:lux, :api_keys, []) |> Keyword.get(:openrouter)
          },
          config
        )
      )

    messages = config.messages ++ [%{role: "user", content: prompt}]
    tools_config = build_tools_config(tools)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        temperature: config.temperature
      }
      |> maybe_add_max_tokens(config)
      |> maybe_add_seed(config)
      |> maybe_add_tools(tools_config, config.tool_choice)
      |> maybe_add_response_format(config)

    headers = build_headers(config)

    [
      url: @endpoint,
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
        {:error, {status, inspect(body)}}

      {:error, error} ->
        Logger.error("OpenRouter API error: #{inspect(error)}")
        {:error, "OpenRouter error: #{inspect(error)}"}
    end
  end

  defp build_headers(%Config{api_key: api_key, site_url: site_url, site_name: site_name}) do
    base = [
      {"Authorization", "Bearer #{Lux.Config.resolve(api_key)}"},
      {"Content-Type", "application/json"},
      {"HTTP-Referer", site_url || @app_url},
      {"X-Title", site_name || @app_name}
    ]

    base
  end

  defp maybe_add_max_tokens(body, %Config{max_tokens: nil}), do: body
  defp maybe_add_max_tokens(body, %Config{max_tokens: n}), do: Map.put(body, :max_tokens, n)

  defp maybe_add_seed(body, %Config{seed: nil}), do: body
  defp maybe_add_seed(body, %Config{seed: s}), do: Map.put(body, :seed, s)

  defp maybe_add_tools(body, [], _), do: body

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
    Map.put(body, :response_format, %{type: "json_schema", json_schema: schema})
  end

  defp maybe_add_response_format(body, %Config{json_response: true}) do
    Map.put(
      %{body | messages: Enum.map(body.messages, &%{&1 | content: &1.content <> "\n Reply in json format"})},
      :response_format,
      %{type: "json_object"}
    )
  end

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

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
  end

  defp parse_content(nil), do: {:ok, nil}

  defp parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, "failed to parse content: #{inspect(content)}"}
    end
  end

  defp execute_tool_calls(nil), do: {:ok, nil}

  defp execute_tool_calls(tool_calls) when is_list(tool_calls) do
    tool_calls
    |> Enum.map(&execute_tool_call/1)
    |> Enum.reduce({:ok, []}, fn
      {:ok, result, _log}, {:ok, results} -> {:ok, [result | results]}
      {:ok, result}, {:ok, results} -> {:ok, [result | results]}
      error, _ -> error
    end)
  end

  defp execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
    args = Jason.decode!(args)

    tool_name
    |> String.replace("_", ".")
    |> List.wrap()
    |> Module.concat()
    |> Code.ensure_loaded()
    |> case do
      {:module, mod} -> execute_tool(mod, args)
      {:error, _} -> {:error, "Failed to load tool: #{tool_name}"}
    end
  end

  defp execute_tool(module, args) do
    cond do
      Lux.prism?(module) -> module.handler(args, nil)
      Lux.beam?(module) -> module.run(args, nil)
      Lux.lens?(module) -> module.focus(args)
      true -> {:error, "Unknown tool type: #{inspect(module)}"}
    end
  end

  def tool_to_function(tool_module) when is_atom(tool_module) do
    cond do
      Lux.prism?(tool_module) -> tool_to_function(tool_module.view())
      Lux.beam?(tool_module) -> tool_to_function(tool_module.view())
      Lux.lens?(tool_module) -> tool_to_function(tool_module.view())
      true -> raise "Unsupported tool type: #{inspect(tool_module)}"
    end
  end

  def tool_to_function(%Beam{module_name: name, description: desc, input_schema: schema}) do
    %{
      type: "function",
      function: %{name: String.replace(name, ".", "_"), description: desc || "", parameters: schema}
    }
  end

  def tool_to_function(%Prism{module_name: name, description: desc, input_schema: schema}) do
    %{
      type: "function",
      function: %{name: String.replace(name, ".", "_"), description: desc || "", parameters: schema}
    }
  end

  def tool_to_function(%Lens{module_name: name, description: desc, schema: schema}) do
    %{
      type: "function",
      function: %{name: String.replace(name, ".", "_"), description: desc || "", parameters: schema}
    }
  end
end
