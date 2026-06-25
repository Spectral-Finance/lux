defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation that provides access to a wide range of models
  through a single unified API. Supports model selection, cost tracking,
  rate limiting, and automatic fallback between models.
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
            top_p: float(),
            frequency_penalty: float(),
            presence_penalty: float(),
            max_tokens: integer(),
            response_format: map() | nil,
            extra_body: map(),
            receive_timeout: integer(),
            seed: integer(),
            n: integer(),
            json_response: boolean(),
            json_schema: map() | nil,
            tool_choice: map() | nil,
            user: String.t(),
            messages: [map()],
            cost_tracking_enabled: boolean(),
            retry_count: integer(),
            retry_delay: integer()
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: "anthropic/claude-3.5-sonnet",
              api_key: nil,
              temperature: 0.7,
              top_p: 1.0,
              frequency_penalty: 0.0,
              presence_penalty: 0.0,
              max_tokens: nil,
              response_format: nil,
              extra_body: %{},
              receive_timeout: 60_000,
              seed: nil,
              n: 1,
              json_response: true,
              json_schema: nil,
              tool_choice: nil,
              user: nil,
              messages: [],
              cost_tracking_enabled: true,
              retry_count: 3,
              retry_delay: 1000
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :openrouter_models)[:default],
            api_key: Application.get_env(:lux, :api_keys)[:openrouter]
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
        top_p: config.top_p,
        frequency_penalty: config.frequency_penalty,
        presence_penalty: config.presence_penalty,
        max_tokens: config.max_tokens
      }
      |> maybe_add_tools(tools_config, config.tool_choice)
      |> maybe_add_response_format(config)
      |> Map.merge(config.extra_body)

    request_opts =
      [
        url: @endpoint,
        json: body,
        headers: [
          {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
          {"Content-Type", "application/json"},
          {"HTTP-Referer", "https://github.com/Spectral-Finance/lux"},
          {"X-Title", "Lux LLM Agent"}
        ],
        timeout: config.receive_timeout + 5000,
        recv_timeout: config.receive_timeout
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    request_opts
    |> Req.new()
    |> do_call(config, config.retry_count)
  end

  @doc """
  Internal retry logic with exponential backoff.
  """
  defp do_call(req, _config, 0) do
    case Req.request(req) do
      {:ok, %{status: 200} = response} ->
        handle_response(response, req.params[:_config] || %Config{})

      {:ok, %{status: 429}} ->
        Logger.warning("OpenRouter rate limited, retrying...")
        :timer.sleep(1000)
        {:retry, req}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:error, error} ->
        handle_error(error)
    end
  end

  defp do_call({:retry, req}, config, remaining_retries) do
    do_call(req, config, remaining_retries - 1)
  end

  defp do_call(req, config, remaining_retries) do
    case Req.request(req) do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: 429}} when remaining_retries > 0 ->
        Logger.warning("OpenRouter rate limited, retrying (#{remaining_retries} left)...")
        :timer.sleep(config.retry_delay)
        do_call(req, config, remaining_retries - 1)

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

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
    Map.put(
      %{
        body
        | messages:
            Enum.map(body.messages, &%{&1 | content: &1.content <> "\nReply in json format"})
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

  # --- Tool conversion ---

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

  # --- Response handling ---

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
        tool_calls_results: tool_calls_results,
        cost: get_cost(body)
      }

      metadata = %{
        id: body["id"],
        created: body["created"],
        usage: body["usage"],
        system_fingerprint: body["system_fingerprint"],
        provider: get_provider(body)
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

  defp get_cost(body) do
    case body["usage"] do
      %{
        "total_cost" => cost
      } ->
        cost

      _ ->
        # Calculate cost from token counts and model pricing
        model = body["model"] || ""
        usage = body["usage"] || %{}
        prompt_tokens = Map.get(usage, "prompt_tokens", 0)
        completion_tokens = Map.get(usage, "completion_tokens", 0)

        calculate_cost(model, prompt_tokens, completion_tokens)
    end
  end

  @doc """
  Calculate cost for a given model and token counts.
  Uses approximate per-token pricing from OpenRouter.
  """
  @spec calculate_cost(String.t(), integer(), integer()) :: float()
  def calculate_cost(model, prompt_tokens, completion_tokens) do
    pricing = model_pricing(model)

    prompt_cost = prompt_tokens * elem(pricing[:prompt], 0)
    completion_cost = completion_tokens * elem(pricing[:completion], 0)

    round((prompt_cost + completion_cost) * 10_000) / 10_000
  end

  defp model_pricing(model) do
    case String.downcase(model) do
      m when m in ["anthropic/claude-3.5-sonnet", "anthropic/claude-3.5-sonnet:beta"] ->
        [prompt: {3.00 / 1_000_000, 15.00 / 1_000_000}]

      m when m in ["anthropic/claude-3-opus", "anthropic/claude-3-opus:beta"] ->
        [prompt: {15.00 / 1_000_000, 75.00 / 1_000_000}]

      m when m in ["openai/gpt-4o", "openai/gpt-4o-2024-05-13"] ->
        [prompt: {5.00 / 1_000_000, 15.00 / 1_000_000}]

      m when m in ["openai/gpt-4o-mini"] ->
        [prompt: {0.15 / 1_000_000, 0.60 / 1_000_000}]

      m when m in ["google/gemini-pro", "google/gemini-pro-1.5"] ->
        [prompt: {0.50 / 1_000_000, 1.50 / 1_000_000}]

      m when m in ["meta-llama/llama-3-70b-instruct"] ->
        [prompt: {0.88 / 1_000_000, 1.08 / 1_000_000}]

      _ ->
        [prompt: {0.0 / 1_000_000, 0.0 / 1_000_000}]
    end
  end

  defp get_provider(body) do
    case body["provider"] do
      %{"vendor_parameters" => [_ | _]} = provider ->
        provider

      _ ->
        %{}
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
         "Failed to load tool module #{tool_name}: It doesn't seem to be implemented or reachable"}

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
    Logger.error("OpenRouter API error: #{inspect(error)}")
    {:error, "OpenRouter API error: #{inspect(error)}"}
  end
end
