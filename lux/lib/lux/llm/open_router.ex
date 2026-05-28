defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  OpenRouter LLM implementation that provides access to multiple LLM models through
  a single unified API. Supports all OpenAI-compatible features including tool calling,
  JSON responses, and streaming.

  OpenRouter aggregates models from OpenAI, Anthropic, Google, Meta, Mistral, and more,
  providing automatic failover, cost optimization, and unified billing.

  ## Configuration

      config :lux, :api_keys,
        openrouter: "sk-or-..."

      config :lux, :openrouter_models,
        default: "openai/gpt-4o",
        fallback: "anthropic/claude-3.5-sonnet"

  ## Usage

      Lux.LLM.OpenRouter.call(prompt, tools, %{
        model: "openai/gpt-4o",
        api_key: "sk-or-...",
        temperature: 0.7
      })
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
    Configuration module for OpenRouter.
    """

    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            frequency_penalty: float(),
            receive_timeout: integer(),
            seed: integer(),
            n: integer(),
            json_response: boolean(),
            json_schema: map(),
            max_tokens: integer(),
            tool_choice: map(),
            user: String.t(),
            messages: [map()],
            # OpenRouter-specific options
            route: String.t() | nil,
            provider_preferences: map() | nil,
            transforms: [String.t()] | nil,
            models: [String.t()] | nil,
            fallbacks: [String.t()] | nil,
            cost_tracking: boolean()
          }

    defstruct endpoint: "https://openrouter.ai/api/v1/chat/completions",
              model: nil,
              api_key: nil,
              temperature: 0.7,
              frequency_penalty: 0.0,
              receive_timeout: 60_000,
              seed: nil,
              n: 1,
              json_response: true,
              json_schema: nil,
              max_tokens: nil,
              tool_choice: nil,
              user: nil,
              messages: [],
              # OpenRouter-specific
              route: nil,
              provider_preferences: nil,
              transforms: nil,
              models: nil,
              fallbacks: nil,
              cost_tracking: true
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :openrouter_models)[:default] || "openai/gpt-4o",
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
        frequency_penalty: config.frequency_penalty,
        max_tokens: config.max_tokens
      }
      |> maybe_add_tools(tools_config, config.tool_choice)
      |> maybe_add_response_format(config)
      |> maybe_add_openrouter_opts(config)

    headers = build_headers(config)

    [
      url: config.endpoint,
      json: body,
      headers: headers
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
        {:error, {status, "Unexpected response: #{inspect(body)}"}}

      {:error, error} ->
        handle_error(error)
    end
  end

  @doc """
  Lists available models from OpenRouter.

  ## Options
    - `:api_key` - OpenRouter API key
    - `:filter` - Filter models by provider or capability
  """
  def list_models(opts \\ []) do
    api_key = opts[:api_key] || Application.get_env(:lux, :api_keys)[:openrouter]

    headers = [
      {"Authorization", "Bearer #{Lux.Config.resolve(api_key)}"},
      {"Content-Type", "application/json"}
    ]

    case Req.get(@models_endpoint, headers: headers) do
      {:ok, %{status: 200, body: %{"data" => models}}} ->
        filtered = if opts[:filter], do: filter_models(models, opts[:filter]), else: models
        {:ok, filtered}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, "Failed to fetch models: #{inspect(body)}"}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets cost information for a specific model.

  ## Example

      {:ok, cost} = Lux.LLM.OpenRouter.get_model_cost("openai/gpt-4o")
      # => %{"prompt" => "0.000005", "completion" => "0.000015"}
  """
  def get_model_cost(model_id) do
    case list_models() do
      {:ok, models} ->
        case Enum.find(models, fn m -> m["id"] == model_id end) do
          nil -> {:error, :model_not_found}
          model -> {:ok, Map.get(model, "pricing", %{})}
        end

      error ->
        error
    end
  end

  @doc """
  Estimates the cost of a request based on token counts and model pricing.

  ## Example

      cost = Lux.LLM.OpenRouter.estimate_cost("openai/gpt-4o", 1000, 500)
      # => %{"prompt_cost" => 0.005, "completion_cost" => 0.0075, "total" => 0.0125}
  """
  def estimate_cost(model_id, prompt_tokens, completion_tokens) do
    case get_model_cost(model_id) do
      {:ok, pricing} ->
        prompt_cost = parse_cost(pricing["prompt"]) * prompt_tokens
        completion_cost = parse_cost(pricing["completion"]) * completion_tokens

        %{
          "prompt_cost" => prompt_cost,
          "completion_cost" => completion_cost,
          "total" => prompt_cost + completion_cost,
          "currency" => "USD"
        }

      error ->
        error
    end
  end

  # Private functions

  defp build_headers(config) do
    [
      {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
      {"Content-Type", "application/json"},
      {"HTTP-Referer", "https://github.com/Spectral-Finance/lux"},
      {"X-Title", "Lux Framework"}
    ]
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
    # OpenRouter supports JSON mode like OpenAI
    Map.put(body, :response_format, %{type: "json_object"})
  end

  defp maybe_add_openrouter_opts(body, config) do
    body
    |> maybe_add_field(:route, config.route)
    |> maybe_add_field(:provider_preferences, config.provider_preferences)
    |> maybe_add_field(:transforms, config.transforms)
    |> maybe_add_field(:models, config.models)
    |> maybe_add_field(:fallbacks, config.fallbacks)
  end

  defp maybe_add_field(body, _key, nil), do: body
  defp maybe_add_field(body, key, value), do: Map.put(body, key, value)

  defp handle_response(%{body: body}, config) do
    case body do
      %{"choices" => [%{"message" => message} | _], "usage" => usage} ->
        # Track costs if enabled
        if config.cost_tracking do
          track_cost(config.model, usage)
        end

        response = %Lux.LLM.Response{
          content: message["content"],
          tool_calls: parse_tool_calls(message["tool_calls"]),
          finish_reason: get_in(body, ["choices", Access.at(0), "finish_reason"])
        }

        {:ok, response}

      %{"error" => %{"message" => message}} ->
        {:error, message}

      _ ->
        {:error, "Unexpected response format: #{inspect(body)}"}
    end
  end

  defp parse_tool_calls(nil), do: []
  defp parse_tool_calls([]), do: []

  defp parse_tool_calls(tool_calls) when is_list(tool_calls) do
    Enum.map(tool_calls, fn tc ->
      %{
        type: "function",
        name: get_in(tc, ["function", "name"]) || "",
        params: parse_params(get_in(tc, ["function", "arguments"]))
      }
    end)
  end

  defp parse_params(nil), do: %{}

  defp parse_params(arguments) when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, parsed} -> parsed
      _ -> %{}
    end
  end

  defp parse_params(arguments), do: arguments

  defp tool_to_function(%Lux.Prism{} = prism) do
    %{
      type: "function",
      function: %{
        name: String.replace(prism.name, ".", "_"),
        description: prism.description,
        parameters: prism.input_schema || %{}
      }
    }
  end

  defp tool_to_function(%Lux.Beam{} = beam) do
    %{
      type: "function",
      function: %{
        name: String.replace(beam.name, ".", "_"),
        description: beam.description,
        parameters: beam.input_schema || %{}
      }
    }
  end

  defp tool_to_function(%Lux.Lens{} = lens) do
    %{
      type: "function",
      function: %{
        name: String.replace(lens.name, ".", "_"),
        description: lens.description,
        parameters: lens.input_schema || %{}
      }
    }
  end

  defp handle_error(%Req.TransportError{reason: reason}) do
    {:error, "Transport error: #{inspect(reason)}"}
  end

  defp handle_error(error) do
    {:error, "Request error: #{inspect(error)}"}
  end

  # Cost tracking helpers

  defp track_cost(model, %{"prompt_tokens" => prompt, "completion_tokens" => completion} = usage) do
    total_tokens = Map.get(usage, "total_tokens", prompt + completion)

    Logger.info(
      "OpenRouter cost tracking: model=#{model} prompt_tokens=#{prompt} completion_tokens=#{completion} total_tokens=#{total_tokens}"
    )

    # Emit telemetry event for cost tracking
    :telemetry.execute(
      [:lux, :llm, :openrouter, :request],
      %{
        prompt_tokens: prompt,
        completion_tokens: completion,
        total_tokens: total_tokens
      },
      %{model: model}
    )
  end

  defp track_cost(_model, _usage), do: :ok

  defp filter_models(models, filter) when is_binary(filter) do
    Enum.filter(models, fn m ->
      String.contains?(String.downcase(m["id"]), String.downcase(filter))
    end)
  end

  defp filter_models(models, filter) when is_list(filter) do
    Enum.filter(models, fn m ->
      Enum.any?(filter, fn f ->
        String.contains?(String.downcase(m["id"]), String.downcase(f))
      end)
    end)
  end

  defp parse_cost(nil), do: 0.0

  defp parse_cost(cost) when is_binary(cost) do
    case Float.parse(cost) do
      {value, _} -> value
      :error -> 0.0
    end
  end

  defp parse_cost(cost) when is_number(cost), do: cost
end
