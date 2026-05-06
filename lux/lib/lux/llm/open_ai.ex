defmodule Lux.LLM.OpenAI do
  @moduledoc """
  OpenAI LLM implementation that supports passing Beams, Prisms, and Lenses as tools.
  """

  
  @behaviour Lux.LLM.Provider

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @endpoint "https://api.openai.com/v1/chat/completions"

  defmodule Config do
    @moduledoc """
    Configuration module for OpenAI.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            frequency_penalty: float(),
            reasoning_mode: boolean(),
            reasoning_effort: String.t(),
            receive_timeout: integer(),
            seed: integer(),
            n: integer(),
            json_response: boolean(),
            json_schema: map(),
            max_tokens: integer(),
            tool_choice: map(),
            user: String.t(),
            messages: [map()]
          }

    defstruct endpoint: "https://api.openai.com/v1/chat/completions",
              model: "gpt-4",
              api_key: nil,
              temperature: 0.7,
              frequency_penalty: 0.0,
              reasoning_mode: false,
              reasoning_effort: "medium",
              receive_timeout: 60_000,
              seed: nil,
              n: 1,
              json_response: true,
              json_schema: nil,
              max_tokens: nil,
              tool_choice: nil,
              user: nil,
              messages: []
  end

  # ──────────────────────────────────────
  # Lux.LLM.Provider callbacks
  # ──────────────────────────────────────

  @impl Lux.LLM.Provider
  def models do
    [
      "gpt-4o",
      "gpt-4o-mini",
      "gpt-4-turbo",
      "gpt-4",
      "gpt-4.1",
      "gpt-4.1-nano",
      "gpt-4.1-mini",
      "o3",
      "o3-mini",
      "o1",
      "o1-mini"
    ]
  end

  @impl Lux.LLM.Provider
  def models(criteria) do
    supported = models()

    Enum.reduce(criteria, supported, fn
      {:capability, :vision}, acc ->
        # Models that support vision
        Enum.filter(acc, &(&1 in ~w(gpt-4o gpt-4o-mini gpt-4-turbo gpt-4.1)))

      {:capability, :json_mode}, acc ->
        # All GPT-4 models support JSON mode
        Enum.filter(acc, &(String.starts_with?(&1, "gpt-4") || String.starts_with?(&1, "o")))

      {:capability, :tools}, acc ->
        # All models support tool calling
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
  def cost("gpt-4o"), do: {:ok, %{model: "gpt-4o", input_per_1k_tokens: 0.0025, output_per_1k_tokens: 0.01, currency: "USD"}}
  def cost("gpt-4o-mini"), do: {:ok, %{model: "gpt-4o-mini", input_per_1k_tokens: 0.00015, output_per_1k_tokens: 0.0006, currency: "USD"}}
  def cost("gpt-4-turbo"), do: {:ok, %{model: "gpt-4-turbo", input_per_1k_tokens: 0.01, output_per_1k_tokens: 0.03, currency: "USD"}}
  def cost("gpt-4"), do: {:ok, %{model: "gpt-4", input_per_1k_tokens: 0.03, output_per_1k_tokens: 0.06, currency: "USD"}}
  def cost("gpt-4.1"), do: {:ok, %{model: "gpt-4.1", input_per_1k_tokens: 0.002, output_per_1k_tokens: 0.008, currency: "USD"}}
  def cost("gpt-4.1-mini"), do: {:ok, %{model: "gpt-4.1-mini", input_per_1k_tokens: 0.0004, output_per_1k_tokens: 0.0016, currency: "USD"}}
  def cost("gpt-4.1-nano"), do: {:ok, %{model: "gpt-4.1-nano", input_per_1k_tokens: 0.0001, output_per_1k_tokens: 0.0004, currency: "USD"}}
  def cost("o3"), do: {:ok, %{model: "o3", input_per_1k_tokens: 0.01, output_per_1k_tokens: 0.04, currency: "USD"}}
  def cost("o3-mini"), do: {:ok, %{model: "o3-mini", input_per_1k_tokens: 0.0011, output_per_1k_tokens: 0.0044, currency: "USD"}}
  def cost("o1"), do: {:ok, %{model: "o1", input_per_1k_tokens: 0.015, output_per_1k_tokens: 0.06, currency: "USD"}}
  def cost("o1-mini"), do: {:ok, %{model: "o1-mini", input_per_1k_tokens: 0.0011, output_per_1k_tokens: 0.0044, currency: "USD"}}
  def cost(_), do: {:error, :unknown_model}

  @impl Lux.LLM.Provider
  def capabilities do
    [:chat, :tools, :streaming, :vision, :json_mode]
  end

  @impl Lux.LLM.Provider
  def default_config do
    %Config{}
  end

  @impl Lux.LLM.Provider
  def metadata do
    %{
      name: "OpenAI",
      module: __MODULE__,
      description: "OpenAI GPT-4 and o-series models",
      models: models(),
      capabilities: capabilities(),
      cost_per_1k_input_tokens: 0.0025,
      cost_per_1k_output_tokens: 0.01,
      priority: 1,
      enabled: true,
      tags: ["openai", "gpt", "o-series"]
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
            model: Application.get_env(:lux, :open_ai_models)[:default],
            api_key: Application.get_env(:lux, :api_keys)[:openai]
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
        max_tokens: config.max_tokens
      }
      |> maybe_add_tools(tools_config, config.tool_choice)
      |> maybe_add_response_format(config)

    [
      url: @endpoint,
      json: body,
      headers: [
        {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

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
    # OpenAI requires the user to specify the format of the response in the prompt in
    # case json_schema is nil. We must mention json "somewere", they say.
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
        # OpenAI function names must be [a-zA-Z0-9_-]
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

  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} ->
        {:ok, structured_output}

      {:error, _} ->
        {:error, "failed to parse content: #{inspect(content)}"}
    end
  end

  def parse_content(_), do: {:ok, nil}

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

  def execute_tool_call(%{"function" => %{"name" => tool_name, "arguments" => args}}) do
    args = Jason.decode!(args)

    execute_tool(tool_name, args, nil)
  end

  def execute_tool(tool_name, args, ctx \\ nil)

  def execute_tool(tool_name, args, ctx) when is_binary(tool_name) do
    # For now tools are only supported as modules.
    # For Bros we should support a way to load tool definitions from some register as well
    # and build them at runtime.
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
    Logger.error("OpenAI API error: #{inspect(error)}")
    {:error, "OpenAI API error: #{inspect(error)}"}
  end
end
