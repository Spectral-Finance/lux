defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation providing access to 100+ AI models through a unified API.

  OpenRouter acts as a proxy/router to models from OpenAI, Anthropic, Google, Meta, Mistral,
  and many others. It uses the same request/response format as OpenAI's chat completions API
  but routes to the selected provider automatically.

  ## Configuration

      config :lux, :open_router,
        api_key: "sk-or-...",
        default_model: "openai/gpt-4o",
        site_url: "https://your-site.com",  # optional, for attribution
        site_name: "Your App"               # optional, for attribution

  ## Supported Models (examples)

  - `openai/gpt-4o` — OpenAI GPT-4o
  - `openai/gpt-4o-mini` — OpenAI GPT-4o Mini (cost-optimized)
  - `anthropic/claude-3-5-sonnet` — Anthropic Claude 3.5 Sonnet
  - `anthropic/claude-3-haiku` — Anthropic Claude 3 Haiku
  - `google/gemini-pro-1.5` — Google Gemini Pro 1.5
  - `meta-llama/llama-3.1-70b-instruct` — Meta Llama 3.1 70B
  - `mistralai/mistral-7b-instruct` — Mistral 7B Instruct
  - `deepseek/deepseek-r1` — DeepSeek R1

  Use `auto` as the model to let OpenRouter pick the best model for your prompt.

  ## Cost Tracking

  OpenRouter returns cost data in the `usage` field. The response metadata includes
  `total_cost` in USD for each request, enabling accurate cost tracking.

  ## Example

      iex> Lux.LLM.OpenRouter.call(
      ...>   "What is the capital of France?",
      ...>   [],
      ...>   %{model: "openai/gpt-4o-mini", json_response: false}
      ...> )
      {:ok, %Lux.Signal{
        payload: %{content: %{"answer" => "Paris"}, model: "openai/gpt-4o-mini", ...},
        metadata: %{usage: %{"total_tokens" => 42, "cost" => 0.000012}, ...}
      }}
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
  @models_endpoint "https://openrouter.ai/api/v1/models"

  defmodule Config do
    @moduledoc """
    Configuration for the OpenRouter LLM client.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            site_url: String.t() | nil,
            site_name: String.t() | nil,
            temperature: float(),
            frequency_penalty: float(),
            receive_timeout: integer(),
            seed: integer() | nil,
            n: integer(),
            json_response: boolean(),
            json_schema: map() | nil,
            max_tokens: integer() | nil,
            tool_choice: map() | atom() | String.t() | nil,
            messages: [map()],
            route: String.t() | nil,
            transforms: [String.t()]
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: "openai/gpt-4o-mini",
              api_key: nil,
              site_url: nil,
              site_name: nil,
              temperature: 0.7,
              frequency_penalty: 0.0,
              receive_timeout: 60_000,
              seed: nil,
              n: 1,
              json_response: true,
              json_schema: nil,
              max_tokens: nil,
              tool_choice: nil,
              messages: [],
              route: nil,
              transforms: []
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model:
              Application.get_env(:lux, :open_router, [])[:default_model] ||
                "openai/gpt-4o-mini",
            api_key: Application.get_env(:lux, :open_router, [])[:api_key],
            site_url: Application.get_env(:lux, :open_router, [])[:site_url],
            site_name: Application.get_env(:lux, :open_router, [])[:site_name]
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
      |> maybe_add_route(config.route)
      |> maybe_add_transforms(config.transforms)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    headers =
      [
        {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
        {"Content-Type", "application/json"}
      ]
      |> maybe_add_site_headers(config)

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

      {:ok, %{status: 402}} ->
        {:error, :insufficient_credits}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Lists all available models on OpenRouter with pricing and context window info.

  Returns a list of models with their IDs, context lengths, and per-token pricing.

  ## Example

      iex> Lux.LLM.OpenRouter.list_models()
      {:ok, [
        %{
          id: "openai/gpt-4o",
          name: "GPT-4o",
          context_length: 128000,
          pricing: %{prompt: "0.000005", completion: "0.000015"}
        },
        ...
      ]}
  """
  def list_models(api_key \\ nil) do
    resolved_key =
      api_key ||
        Application.get_env(:lux, :open_router, [])[:api_key]

    headers = [
      {"Authorization", "Bearer #{Lux.Config.resolve(resolved_key)}"},
      {"Content-Type", "application/json"}
    ]

    [url: @models_endpoint, headers: headers]
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: %{"data" => models}}} ->
        formatted =
          Enum.map(models, fn m ->
            %{
              id: m["id"],
              name: m["name"],
              context_length: m["context_length"],
              pricing: m["pricing"],
              description: m["description"]
            }
          end)

        {:ok, formatted}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Returns the estimated cost for a request based on token counts and model pricing.

  This is a helper for pre-estimating costs before making a request.
  """
  def estimate_cost(model, prompt_tokens, completion_tokens) do
    # Rough pricing in USD per token for common models
    pricing = %{
      "openai/gpt-4o" => %{prompt: 0.000005, completion: 0.000015},
      "openai/gpt-4o-mini" => %{prompt: 0.00000015, completion: 0.0000006},
      "anthropic/claude-3-5-sonnet" => %{prompt: 0.000003, completion: 0.000015},
      "anthropic/claude-3-haiku" => %{prompt: 0.00000025, completion: 0.00000125},
      "meta-llama/llama-3.1-70b-instruct" => %{prompt: 0.0000005, completion: 0.0000015},
      "mistralai/mistral-7b-instruct" => %{prompt: 0.00000006, completion: 0.00000006}
    }

    case Map.get(pricing, model) do
      nil ->
        {:error, :unknown_model}

      %{prompt: prompt_rate, completion: completion_rate} ->
        cost = prompt_tokens * prompt_rate + completion_tokens * completion_rate
        {:ok, Float.round(cost, 8)}
    end
  end

  # Private helpers

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

  defp maybe_add_route(body, nil), do: body
  defp maybe_add_route(body, route), do: Map.put(body, :route, route)

  defp maybe_add_transforms(body, []), do: body
  defp maybe_add_transforms(body, transforms), do: Map.put(body, :transforms, transforms)

  defp maybe_add_site_headers(headers, %Config{site_url: nil, site_name: nil}), do: headers

  defp maybe_add_site_headers(headers, config) do
    headers
    |> maybe_add_header("HTTP-Referer", config.site_url)
    |> maybe_add_header("X-Title", config.site_name)
  end

  defp maybe_add_header(headers, _name, nil), do: headers
  defp maybe_add_header(headers, name, value), do: [{name, value} | headers]

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

  def tool_to_function(%Beam{
        module_name: name,
        description: description,
        input_schema: input_schema
      }) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  def tool_to_function(%Prism{
        module_name: name,
        description: description,
        input_schema: input_schema
      }) do
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

  defp handle_response(%{body: body}, config) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message, "finish_reason" => finish_reason} <- choice,
         {:ok, content} <- parse_content(message["content"], config),
         {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
      usage = body["usage"] || %{}

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
        usage: usage,
        total_cost: Map.get(usage, "cost"),
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

  defp parse_content(content, %Config{json_response: false}) when is_binary(content) do
    # Try JSON parse first; wrap in map if it's plain text (schema requires object or null)
    case Jason.decode(content) do
      {:ok, structured} when is_map(structured) -> {:ok, structured}
      {:ok, value} -> {:ok, %{"value" => value}}
      {:error, _} -> {:ok, %{"text" => content}}
    end
  end

  defp parse_content(content, _config) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured} when is_map(structured) -> {:ok, structured}
      {:ok, value} -> {:ok, %{"value" => value}}
      {:error, _} -> {:error, "failed to parse JSON content: #{inspect(content)}"}
    end
  end

  defp parse_content(_, _), do: {:ok, nil}

  def execute_tool_calls(tool_calls) when is_list(tool_calls) do
    tool_calls
    |> Enum.map(&execute_tool_call/1)
    |> Enum.reduce({:ok, []}, fn
      {:ok, result, _log}, {:ok, results} -> {:ok, [result | results]}
      {:ok, result}, {:ok, results} -> {:ok, [result | results]}
      error, _ -> error
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
        {:error, "Failed to load tool module #{tool_name}"}

      {:error, error} ->
        {:error, "Failed to load tool module #{tool_name}: #{inspect(error)}"}
    end
  end

  def execute_tool(tool_module, args, ctx) when is_atom(tool_module) do
    cond do
      Lux.prism?(tool_module) -> tool_module.handler(args, ctx)
      Lux.beam?(tool_module) -> tool_module.run(args, ctx)
      Lux.lens?(tool_module) -> tool_module.focus(args)
      true -> {:error, "Tool #{tool_module} is not a valid Beam, Prism, or Lens"}
    end
  end

  defp handle_error(error) do
    Logger.error("OpenRouter API error: #{inspect(error)}")
    {:error, "OpenRouter API error: #{inspect(error)}"}
  end
end
