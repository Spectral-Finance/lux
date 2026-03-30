defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation that supports passing Beams, Prisms, and Lenses as tools.
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
  @default_model "anthropic/claude-3.5-sonnet"

  defmodule Config do
    @moduledoc """
    Configuration for OpenRouter provider.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t() | nil,
            temperature: float(),
            max_tokens: integer() | nil,
            tools: boolean(),
            tool_choice: :auto | :none | String.t() | nil,
            stream: boolean(),
            json_mode: boolean(),
            site_url: String.t() | nil,
            site_name: String.t() | nil,
            route: String.t() | nil,
            retries: integer(),
            messages: [map()]
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: "anthropic/claude-3.5-sonnet",
              api_key: nil,
              temperature: 0.7,
              max_tokens: nil,
              tools: true,
              tool_choice: :auto,
              stream: false,
              json_mode: false,
              site_url: nil,
              site_name: nil,
              route: nil,
              retries: 3,
              messages: []
  end

  @impl true
  @spec call(binary(), [module()], Config.t() | map()) ::
          {:ok, ResponseSignal.t()} | {:error, term()}
  def call(prompt, tools, config \\ %{}) do
    cfg = build_config(config)

    messages = cfg.messages ++ build_messages(prompt)
    tools_config = if cfg.tools, do: build_tools_config(tools), else: []

    body =
      %{
        model: cfg.model,
        messages: messages,
        temperature: cfg.temperature
      }
      |> maybe_add(:max_tokens, cfg.max_tokens)
      |> maybe_add_tools(tools_config, cfg.tool_choice)
      |> maybe_add(:stream, cfg.stream)
      |> maybe_add_json_mode(cfg.json_mode)

    headers =
      [
        {"Authorization", "Bearer #{cfg.api_key}"},
        {"Content-Type", "application/json"},
        {"HTTP-Referer", cfg.site_url},
        {"X-OpenRouter-Title", cfg.site_name},
        {"X-OpenRouter-Route", cfg.route}
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) or v == "" end)

    request = Req.new(url: @endpoint, json: body, headers: headers)

    case perform_request(request, cfg) do
      {:ok, %{status: 200} = response} ->
        handle_response(response)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: 403, body: %{"error" => msg}}} ->
        {:error, {:forbidden, msg}}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: %{"error" => msg}}} ->
        {:error, {status, msg}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_config(config) do
    defaults = %{
      model: default_model(),
      api_key: default_api_key()
    }

    struct(Config, Map.merge(defaults, config))
  end

  defp default_model do
    Application.get_env(:lux, :open_router_models, [])
    |> Keyword.get(:default, @default_model)
  end

  defp default_api_key do
    Application.get_env(:lux, :api_keys, [])
    |> Keyword.get(:openrouter, System.get_env("OPENROUTER_API_KEY", ""))
  end

  defp perform_request(request, %{retries: retries}) when retries > 0 do
    case Req.post(request) do
      {:ok, %{status: status}} when status in [429, 500, 502, 503, 504] ->
        Logger.warning("OpenRouter request failed (status #{status}), retrying...")
        perform_request(request, %{retries: retries - 1})

      result ->
        result
    end
  end

  defp perform_request(request, _cfg) do
    Req.post(request)
  end

  @doc """
  Register OpenRouter as a provider in Lux.LLM.ProviderRegistry.

  ## Examples

      iex> Lux.LLM.OpenRouter.register()
      :ok
  """
  @spec register() :: :ok | {:error, term()}
  def register do
    registry().register(:openrouter, %{
      module: __MODULE__,
      models: [
        "anthropic/claude-3.5-sonnet",
        "openai/gpt-4o",
        "openai/gpt-4o-mini",
        "google/gemini-pro",
        "meta-llama/llama-3-70b-instruct",
        "mistralai/mistral-7b-instruct"
      ],
      cost_per_1k_tokens: %{
        "anthropic/claude-3.5-sonnet" => %{input: 0.003, output: 0.015},
        "openai/gpt-4o" => %{input: 0.005, output: 0.015},
        "openai/gpt-4o-mini" => %{input: 0.00015, output: 0.0006},
        "google/gemini-pro" => %{input: 0.00125, output: 0.005},
        "meta-llama/llama-3-70b-instruct" => %{input: 0.0009, output: 0.0009},
        "mistralai/mistral-7b-instruct" => %{input: 0.0002, output: 0.0006}
      },
      max_tokens: 128_000,
      features: [:streaming, :tools, :json_mode],
      priority: 5,
      enabled: true
    })
  end

  # Private helpers

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, _key, ""), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)

  defp maybe_add_tools(body, [], _choice), do: body
  defp maybe_add_tools(body, tools, choice) do
    body
    |> Map.put(:tools, tools)
    |> Map.put(:tool_choice, format_tool_choice(choice))
  end

  defp maybe_add_json_mode(body, true) do
    Map.put(body, :response_format, %{"type" => "json_object"})
  end

  defp maybe_add_json_mode(body, false), do: body

  defp format_tool_choice(:none), do: "none"
  defp format_tool_choice(:auto), do: "auto"
  defp format_tool_choice(name) when is_binary(name), do: name
  defp format_tool_choice(_), do: "auto"

  defp build_messages(prompt), do: [%{role: "user", content: prompt}]

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp tool_to_function({:python, path}) do
    path |> Prism.view() |> tool_to_function()
  end

  def tool_to_function(tool_module) when is_atom(tool_module) and not is_nil(tool_module) do
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
      function: %{
        name: String.replace(name, ".", "_"),
        description: desc || "",
        parameters: schema || %{"type" => "object", "properties" => %{}}
      }
    }
  end

  def tool_to_function(%Prism{module_name: name, description: desc, input_schema: schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: desc || "",
        parameters: schema || %{"type" => "object", "properties" => %{}}
      }
    }
  end

  def tool_to_function(%Lens{name: name, description: desc, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: name || "unnamed_lens",
        description: desc || "",
        parameters: schema || %{"type" => "object", "properties" => %{}}
      }
    }
  end

  defp handle_response(%{body: body}) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message} <- choice,
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
      payload = %{
        content: content,
        model: body["model"] || "unknown",
        finish_reason: choice["finish_reason"],
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
    else
      nil -> {:error, :invalid_response}
      %{} -> {:error, :invalid_response}
      {:error, _} = error -> error
    end
  end

  defp parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:ok, content}
    end
  end

  defp parse_content(nil), do: {:ok, nil}
  defp parse_content(other), do: {:ok, other}

  defp execute_tool_calls(nil), do: {:ok, []}

  defp execute_tool_calls(tool_calls) when is_list(tool_calls) do
    results =
      tool_calls
      |> Enum.map(fn call ->
        Task.async(fn -> execute_tool_call(call) end)
      end)
      |> Task.await_many(timeout: 30_000)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, results}
    else
      {:error, errors}
    end
  end

  defp execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}})
       when is_binary(args) do
    args = Jason.decode!(args)
    execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}})
  end

  defp execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
    execute_tool(tool_name, args, nil)
  end

  defp execute_tool_call(other) do
    {:error, "Malformed tool call: #{inspect(other)}"}
  end

  defp execute_tool(tool_name, args, ctx \\ nil)

  defp execute_tool(tool_name, args, ctx) when is_binary(tool_name) do
    tool_name
    |> String.replace("_", ".")
    |> List.wrap()
    |> Module.concat()
    |> Code.ensure_loaded()
    |> case do
      {:module, module_name} -> execute_tool(module_name, args, ctx)
      {:error, :nofile} -> {:error, "Tool module not found: #{tool_name}"}
      {:error, error} -> {:error, "Failed to load #{tool_name}: #{inspect(error)}"}
    end
  end

  defp execute_tool(module_name, args, ctx) when is_atom(module_name) do
    cond do
      Lux.prism?(module_name) -> module_name.handler(args, ctx)
      Lux.beam?(module_name) -> module_name.run(args, ctx)
      true -> {:error, "Tool #{inspect(module_name)} has no handler/run function"}
    end
  end

  # Allow registry module to be configured for testing
  defp registry,
    do: Application.get_env(:lux, :provider_registry_module, Lux.LLM.ProviderRegistry)
end
