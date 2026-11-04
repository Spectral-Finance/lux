defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI LLM implementation that supports passing Beams, Prisms, and Lenses as tools.

  Provides access to Perplexity's Sonar family of models for knowledge-intensive
  tasks, with optional response streaming and cost tracking.

  ## Configuration

      config :lux, :perplexity_models,
        default: "sonar",
        pro: "sonar-pro"

      config :lux, :api_keys, perplexity: System.get_env("PERPLEXITY_API_KEY")

  ## Streaming

      Lux.LLM.Perplexity.stream("Explain quantum computing", [], config)

  ## Cost tracking

  Every response includes the estimated cost (in USD) in its metadata, computed
  from the token usage and the configured model's per-token price.

  ## Model selection

      Lux.LLM.Perplexity.models()
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  # Estimated pricing per 1,000,000 tokens in USD: %{input:, output:}
  @pricing %{
    "sonar" => %{input: 1.00, output: 1.00},
    "sonar-pro" => %{input: 3.00, output: 15.00},
    "sonar-reasoning-pro" => %{input: 2.00, output: 8.00},
    "sonar-deep-research" => %{input: 2.00, output: 8.00}
  }

  @available_models [
    %{
      id: "sonar",
      name: "Sonar",
      description: "Perplexity's base model for general knowledge tasks."
    },
    %{
      id: "sonar-pro",
      name: "Sonar Pro",
      description: "Higher-quality model for complex knowledge-intensive tasks."
    },
    %{
      id: "sonar-reasoning-pro",
      name: "Sonar Reasoning Pro",
      description: "Reasoning-optimized model for complex multi-step tasks."
    },
    %{
      id: "sonar-deep-research",
      name: "Sonar Deep Research",
      description: "In-depth research model with extensive citations."
    }
  ]

  defmodule Config do
    @moduledoc """
    Configuration module for Perplexity AI.
    """

    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            top_p: float(),
            top_k: integer(),
            max_tokens: integer(),
            stream: boolean(),
            presence_penalty: float(),
            frequency_penalty: float(),
            user: String.t(),
            messages: [map()]
          }

    defstruct endpoint: "https://api.perplexity.ai/chat/completions",
              model: "sonar",
              api_key: nil,
              temperature: 0.7,
              top_p: 0.9,
              top_k: 0,
              max_tokens: nil,
              stream: false,
              presence_penalty: 0.0,
              frequency_penalty: 0.0,
              user: nil,
              messages: []
  end

  ## Public API

  @impl true
  def call(prompt, tools, config) when is_binary(prompt) do
    if String.trim(prompt) == "" do
      {:error, "Perplexity API error: prompt must be a non-empty string, got #{inspect(prompt)}"}
    else
      execute(prompt, tools, config, false)
    end
  end

  def call(_prompt, _tools, _config) do
    {:error, "Perplexity API error: prompt must be a non-empty string, got #{inspect(_prompt)}"}
  end

  def stream(prompt, tools, config) when is_binary(prompt) do
    if String.trim(prompt) == "" do
      {:error, "Perplexity API error: prompt must be a non-empty string, got #{inspect(prompt)}"}
    else
      execute(prompt, tools, config, true)
    end
  end

  def stream(_prompt, _tools, _config) do
    {:error, "Perplexity API error: prompt must be a non-empty string, got #{inspect(_prompt)}"}
  end

  @doc """
  Returns the list of available Perplexity models for model selection.
  """
  def models do
    @available_models
  end

  @doc """
  Returns the estimated per-1M-token pricing for a model: %{input:, output:}.
  """
  def model_price(model) do
    Map.get(@pricing, model, %{input: 0.0, output: 0.0})
  end

  ## Request execution

  defp execute(prompt, tools, config, stream) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :perplexity_models)[:default],
            api_key: Application.get_env(:lux, :api_keys)[:perplexity]
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
        top_k: config.top_k,
        max_tokens: config.max_tokens,
        stream: config.stream || stream,
        presence_penalty: config.presence_penalty,
        frequency_penalty: config.frequency_penalty,
        user: config.user
      }
      |> maybe_add_tools(tools_config)

    headers =
      [
        {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
        {"Content-Type", "application/json"},
        {"Accept", if(stream, do: "text/event-stream", else: "application/json")}
      ]

    request =
      [url: config.endpoint, json: body, headers: headers]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> Req.new()

    case stream do
      true ->
        execute_stream(request, config)

      false ->
        case Req.post(request) do
          {:ok, %{status: 200} = response} ->
            handle_response(response, config)

          {:ok, %{status: 401}} ->
            {:error, :invalid_api_key}

          {:ok, %{status: status, body: body}} ->
            handle_error_body(status, body)

          {:error, error} ->
            handle_error(error)
        end
    end
  end

  defp execute_stream(request, config) do
    case Req.post(request, into: :self) do
      {:ok, %Req.Response{status: 200, body: chunks}} ->
        {:ok, parse_stream(chunks, config)}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %Req.Response{status: status, body: body}} ->
        handle_error_body(status, body)

      {:error, error} ->
        handle_error(error)
    end
  end

  defp parse_stream(chunks, config) do
    raw =
      chunks
      |> Enum.map_join("", fn
        {_key, data} when is_binary(data) -> data
        data when is_binary(data) -> data
        _ -> ""
      end)

    events =
      raw
      |> String.split("\n\n")
      |> Enum.flat_map(fn block ->
        block
        |> String.split("\n")
        |> Enum.filter(fn line -> String.starts_with?(line, "data: ") end)
        |> Enum.map(fn line -> String.trim(String.replace(line, "data: ", "")) end)
        |> Enum.reject(fn payload -> payload == "" or payload == "[DONE]" end)
      end)
      |> Enum.map(fn payload ->
        case Jason.decode(payload) do
          {:ok, decoded} ->
            choice =
              decoded
              |> Map.get("choices", [])
              |> List.first()

            %{
              content: choice |> Map.get("delta", %{}) |> Map.get("content"),
              finish_reason: choice |> Map.get("finish_reason")
            }

          {:error, _} ->
            %{content: nil, finish_reason: nil}
        end
      end)

    usage = %{
      prompt_tokens: 0,
      completion_tokens: 0,
      total_tokens: 0
    }

    cost = calculate_cost(config.model, 0, 0)

    %{
      events: events,
      model: config.model,
      cost_usd: cost,
      usage: usage
    }
  end

  ## Response handling

  defp handle_response(%{body: body}, config) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message, "finish_reason" => finish_reason} <- choice,
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
      usage = body["usage"] || %{}
      prompt_tokens = usage["prompt_tokens"] || 0
      completion_tokens = usage["completion_tokens"] || 0
      cost = calculate_cost(config.model, prompt_tokens, completion_tokens)

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
        system_fingerprint: body["system_fingerprint"],
        cost_usd: cost
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
        {:ok, %{"text" => content}}
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

  defp calculate_cost(model, prompt_tokens, completion_tokens) do
    pricing = Map.get(@pricing, model, %{input: 0.0, output: 0.0})
    (prompt_tokens * pricing.input + completion_tokens * pricing.output) / 1_000_000
  end

  ## Request building

  defp build_messages(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

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

  defp handle_error_body(status, body) do
    message =
      case body do
        %{"error" => %{"message" => message}} when is_binary(message) -> message
        %{"error" => message} when is_binary(message) -> message
        %{"detail" => detail} when is_binary(detail) -> detail
        _ -> "Perplexity API error"
      end

    {:error, {status, message}}
  end

  defp handle_error(error) do
    Logger.error("Perplexity API error: #{inspect(error)}")
    {:error, "Perplexity API error: #{inspect(error)}"}
  end
end
