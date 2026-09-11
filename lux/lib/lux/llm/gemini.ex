defmodule Lux.LLM.Gemini do
  @moduledoc """
  Google Gemini LLM provider implementation for Lux.
  Supports passing Beams, Prisms, and Lenses as tools and returns normalized Lux.Signal outputs.
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

  @default_endpoint "https://generativelanguage.googleapis.com/v1beta/models"

  defmodule Config do
    @moduledoc """
    Configuration struct for Google Gemini API requests.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t() | nil,
            temperature: float(),
            max_tokens: integer() | nil,
            top_p: float() | nil,
            top_k: integer() | nil,
            receive_timeout: integer(),
            json_response: boolean(),
            system: String.t() | nil,
            messages: [map()]
          }

    defstruct endpoint: "https://generativelanguage.googleapis.com/v1beta/models",
              model: "gemini-1.5-flash",
              api_key: nil,
              temperature: 0.7,
              max_tokens: nil,
              top_p: nil,
              top_k: nil,
              receive_timeout: 60_000,
              json_response: false,
              system: nil,
              messages: [],
              plug: nil
  end

  @impl Lux.LLM.Provider
  def id, do: :gemini

  @impl Lux.LLM.Provider
  def models do
    [
      %ModelConfig{
        id: "gemini-1.5-pro",
        name: "Gemini 1.5 Pro",
        provider_id: :gemini,
        cost_per_1k_prompt_tokens: 0.00125,
        cost_per_1k_completion_tokens: 0.005,
        capabilities: [:tools, :json_schema, :vision, :reasoning],
        context_window: 1_000_000
      },
      %ModelConfig{
        id: "gemini-1.5-flash",
        name: "Gemini 1.5 Flash",
        provider_id: :gemini,
        cost_per_1k_prompt_tokens: 0.000075,
        cost_per_1k_completion_tokens: 0.0003,
        capabilities: [:tools, :json_schema, :vision],
        context_window: 1_000_000
      },
      %ModelConfig{
        id: "gemini-2.0-flash",
        name: "Gemini 2.0 Flash",
        provider_id: :gemini,
        cost_per_1k_prompt_tokens: 0.0001,
        cost_per_1k_completion_tokens: 0.0004,
        capabilities: [:tools, :json_schema, :vision],
        context_window: 1_000_000
      }
    ]
  end

  @impl Lux.LLM.Provider
  def call(prompt, tools, config) do
    config = normalize_config(config)
    body = build_request_body(config, prompt, tools)
    req_opts = build_req_opts(config, body)

    Req.post(req_opts)
    |> handle_req_response(config)
  end

  defp normalize_config(config) do
    opts_map =
      case config do
        %_{} -> Map.from_struct(config)
        %{} -> config
        list when is_list(list) -> Enum.into(list, %{})
        _ -> %{}
      end

    default_api_key =
      case Application.get_env(:lux, :api_keys) do
        keys when is_list(keys) -> keys[:gemini] || keys[:google]
        _ -> nil
      end

    struct(
      Config,
      Map.merge(
        %{
          model: Application.get_env(:lux, :gemini_models)[:default] || "gemini-1.5-flash",
          api_key: default_api_key
        },
        opts_map
      )
    )
  end

  defp build_request_body(config, prompt, tools) do
    {system_instruction, contents} = build_contents(prompt, config)
    tools_config = build_tools_config(tools)

    %{
      contents: contents,
      generationConfig: build_generation_config(config)
    }
    |> maybe_add_system_instruction(system_instruction)
    |> maybe_add_tools(tools_config)
  end

  defp build_req_opts(config, body) do
    resolved_model = Lux.Config.resolve(config.model)
    resolved_api_key = Lux.Config.resolve(config.api_key)

    url =
      "#{Lux.Config.resolve(config.endpoint || @default_endpoint)}/#{resolved_model}:generateContent?key=#{resolved_api_key}"

    req_opts =
      [
        url: url,
        json: body,
        headers: [{"Content-Type", "application/json"}],
        receive_timeout: config.receive_timeout
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    if config.plug do
      Keyword.put(req_opts, :plug, config.plug)
    else
      req_opts
    end
  end

  defp handle_req_response({:ok, %{status: 200} = response}, config) do
    handle_response(response, config)
  end

  defp handle_req_response({:ok, %{status: 401}}, _config) do
    {:error, :invalid_api_key}
  end

  defp handle_req_response({:ok, %{status: status, body: %{"error" => %{"message" => message}}}}, _config) do
    {:error, {status, message}}
  end

  defp handle_req_response({:ok, %{status: status, body: body}}, _config) do
    message = if is_map(body), do: Map.get(body, "message", inspect(body)), else: inspect(body)
    {:error, {status, message}}
  end

  defp handle_req_response({:error, error}, _config) do
    handle_error(error)
  end

  defp build_contents(prompt, %Config{messages: messages, system: system}) when is_binary(prompt) do
    system_part = system

    user_content = %{
      role: "user",
      parts: [%{text: prompt}]
    }

    formatted_messages =
      messages
      |> Enum.map(&format_message/1)
      |> Enum.reject(&is_nil/1)

    {system_part, formatted_messages ++ [user_content]}
  end

  defp build_contents(messages, %Config{system: system}) when is_list(messages) do
    {system_from_list, rest_messages} =
      Enum.split_with(messages, fn
        %{role: "system"} -> true
        %{"role" => "system"} -> true
        _ -> false
      end)

    system_part =
      cond do
        is_binary(system) and system != "" ->
          system

        system_from_list != [] ->
          first = List.first(system_from_list)
          Map.get(first, :content) || Map.get(first, "content")

        true ->
          nil
      end

    formatted_contents =
      rest_messages
      |> Enum.map(&format_message/1)
      |> Enum.reject(&is_nil/1)

    {system_part, formatted_contents}
  end

  defp format_message(%{role: role, content: content}) do
    gemini_role = if role in ["assistant", "model"], do: "model", else: "user"
    %{role: gemini_role, parts: [%{text: content}]}
  end

  defp format_message(%{"role" => role, "content" => content}) do
    gemini_role = if role in ["assistant", "model"], do: "model", else: "user"
    %{role: gemini_role, parts: [%{text: content}]}
  end

  defp format_message(msg) when is_binary(msg) do
    %{role: "user", parts: [%{text: msg}]}
  end

  defp format_message(_), do: nil

  defp build_generation_config(config) do
    gen_config = %{
      temperature: config.temperature
    }

    gen_config =
      if config.max_tokens, do: Map.put(gen_config, :maxOutputTokens, config.max_tokens), else: gen_config

    gen_config =
      if config.top_p, do: Map.put(gen_config, :topP, config.top_p), else: gen_config

    gen_config =
      if config.top_k, do: Map.put(gen_config, :topK, config.top_k), else: gen_config

    if config.json_response do
      Map.put(gen_config, :responseMimeType, "application/json")
    else
      gen_config
    end
  end

  defp maybe_add_system_instruction(body, nil), do: body
  defp maybe_add_system_instruction(body, ""), do: body

  defp maybe_add_system_instruction(body, sys_text) when is_binary(sys_text) do
    Map.put(body, :systemInstruction, %{parts: [%{text: sys_text}]})
  end

  defp build_tools_config([]), do: []
  defp build_tools_config(tools) when is_list(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body

  defp maybe_add_tools(body, declarations) do
    Map.put(body, :tools, [%{functionDeclarations: declarations}])
  end

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
      name: String.replace(name, ".", "_"),
      description: description || "",
      parameters: input_schema
    }
  end

  def tool_to_function(%Prism{module_name: name, description: description, input_schema: input_schema}) do
    %{
      name: String.replace(name, ".", "_"),
      description: description || "",
      parameters: input_schema
    }
  end

  def tool_to_function(%Lens{module_name: name, description: description, schema: schema}) do
    %{
      name: String.replace(name, ".", "_"),
      description: description || "",
      parameters: schema
    }
  end

  defp handle_response(%{body: body}, config) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> handle_response(%{body: decoded}, config)
      {:error, _} -> {:error, "Failed to decode response body"}
    end
  end

  defp handle_response(%{body: body}, config) when is_map(body) do
    candidates = Map.get(body, "candidates", [])
    candidate = List.first(candidates) || %{}

    content_parts = get_in(candidate, ["content", "parts"]) || []
    finish_reason = Map.get(candidate, "finishReason", "STOP")

    {text_content, tool_calls} = parse_parts(content_parts)

    parsed_content =
      case parse_content(text_content, config) do
        {:ok, content} -> content
        _ -> %{"text" => text_content}
      end

    tool_calls_results =
      case execute_tool_calls(tool_calls) do
        {:ok, results} -> results
        _ -> nil
      end

    usage_metadata = Map.get(body, "usageMetadata", %{})
    prompt_tokens = Map.get(usage_metadata, "promptTokenCount", 0)
    completion_tokens = Map.get(usage_metadata, "candidatesTokenCount", 0)
    total_tokens = Map.get(usage_metadata, "totalTokenCount", prompt_tokens + completion_tokens)

    cost = calculate_cost(config.model, prompt_tokens, completion_tokens)

    payload = %{
      content: parsed_content,
      model: config.model,
      finish_reason: finish_reason,
      tool_calls: tool_calls,
      tool_calls_results: tool_calls_results
    }

    metadata = %{
      id: "gemini-" <> to_string(System.system_time(:second)),
      provider: :gemini,
      model: config.model,
      usage: %{
        "prompt_tokens" => prompt_tokens,
        "completion_tokens" => completion_tokens,
        "total_tokens" => total_tokens,
        "cost" => cost
      }
    }

    %{
      schema_id: ResponseSignal,
      payload: payload,
      metadata: metadata
    }
    |> Lux.Signal.new()
    |> ResponseSignal.validate()
  end

  defp parse_parts(parts) when is_list(parts) do
    Enum.reduce(parts, {"", []}, fn part, {text_acc, tools_acc} ->
      cond do
        Map.has_key?(part, "text") ->
          text = Map.get(part, "text", "")
          {text_acc <> text, tools_acc}

        Map.has_key?(part, "functionCall") ->
          func_call = Map.get(part, "functionCall")

          tool_call = %{
            "id" => "call_" <> Map.get(func_call, "name", ""),
            "type" => "function",
            "function" => %{
              "name" => Map.get(func_call, "name"),
              "arguments" => Map.get(func_call, "args", %{})
            }
          }

          {text_acc, [tool_call | tools_acc]}

        true ->
          {text_acc, tools_acc}
      end
    end)
  end

  defp parse_parts(_), do: {"", []}

  def parse_content(content, %Config{json_response: true}) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:ok, %{"text" => content}}
    end
  end

  def parse_content(content, _) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      _ -> {:ok, %{"text" => content}}
    end
  end

  def parse_content(content, _), do: {:ok, content}

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
      {:module, module_name} ->
        execute_tool(module_name, args, ctx)

      {:error, _} ->
        {:error, "Failed to load tool module #{tool_name}"}
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
        {:error, "Tool #{tool_module} is not a valid Beam, Prism or Lens"}
    end
  end

  defp calculate_cost(model_name, prompt_tokens, completion_tokens) do
    model_config = Enum.find(models(), &(&1.id == model_name))

    if model_config do
      prompt_cost = (prompt_tokens / 1000) * model_config.cost_per_1k_prompt_tokens
      completion_cost = (completion_tokens / 1000) * model_config.cost_per_1k_completion_tokens
      prompt_cost + completion_cost
    else
      0.0
    end
  end

  defp handle_error(error) do
    Logger.error("Gemini API error: #{inspect(error)}")
    {:error, "Gemini API error: #{inspect(error)}"}
  end
end
