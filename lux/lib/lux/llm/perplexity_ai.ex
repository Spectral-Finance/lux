defmodule Lux.LLM.PerplexityAI do
  @moduledoc """
  Perplexity AI LLM implementation that supports passing Beams, Prisms, and Lenses as tools.

  Perplexity provides search-augmented language models with citation-backed responses.
  The API is OpenAI-compatible, using the same /v1/chat/completions endpoint pattern.

  Supported models:
  - sonar - Fast, cost-effective web-augmented model
  - sonar-pro - More capable web-augmented model
  - sonar-deep-research - Reasoning-heavy web-augmented model
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @endpoint "https://api.perplexity.ai/chat/completions"

  defmodule Config do
    @moduledoc """
    Configuration module for Perplexity AI.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            max_tokens: integer(),
            top_p: float(),
            presence_penalty: float(),
            frequency_penalty: float(),
            stream: boolean(),
            response_format: map() | nil,
            system: String.t() | nil,
            messages: [map()]
          }

    defstruct endpoint: @endpoint,
              model: "sonar",
              api_key: nil,
              temperature: 0.2,
              max_tokens: nil,
              top_p: 1.0,
              presence_penalty: 0.0,
              frequency_penalty: 0.0,
              stream: false,
              response_format: nil,
              system: nil,
              messages: []
  end

  @impl true
  def call(prompt, tools, config) do
    config =
      struct(
        Config,
        Map.merge(
          %{
            model: Application.get_env(:lux, :perplexity_ai_models)[:default],
            api_key: Application.get_env(:lux, :api_keys)[:perplexity]
          },
          config
        )
      )

    messages = config.messages ++ build_messages(prompt)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        temperature: config.temperature,
        max_tokens: config.max_tokens,
        top_p: config.top_p,
        presence_penalty: config.presence_penalty,
        frequency_penalty: config.frequency_penalty,
        stream: config.stream
      }
      |> maybe_add_system(config.system)
      |> maybe_add_tools(tools)
      |> maybe_add_response_format(config.response_format)

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
        handle_response(response)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, response} ->
        Logger.warning("Unexpected Perplexity response: status=#{response.status}")
        {:error, "Unexpected response: #{inspect(response.status)}"}

      {:error, error} ->
        handle_error(error)
    end
  end

  defp build_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_messages(messages) when is_list(messages) do
    Enum.map(messages, fn
      %{role: role, content: _content} = message when role in ["user", "assistant", "system"] ->
        message

      message when is_binary(message) ->
        %{role: "user", content: message}
    end)
  end

  defp maybe_add_system(body, nil), do: body
  defp maybe_add_system(body, system), do: Map.put(body, :system, system)

  defp maybe_add_tools(body, []), do: body

  defp maybe_add_tools(body, tools) do
    tools_config = Enum.map(tools, &tool_to_function/1)
    body
    |> Map.put(:tools, tools_config)
    |> Map.put(:tool_choice, %{type: "auto"})
  end

  defp maybe_add_response_format(body, nil), do: body

  defp maybe_add_response_format(body, %{"type" => "json_object"}) do
    Map.put(body, :response_format, %{type: "json_object"})
  end

  defp maybe_add_response_format(body, _), do: body

  defp tool_to_function(%Beam{name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  defp tool_to_function(%Prism{module_name: name, description: description, input_schema: input_schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: input_schema
      }
    }
  end

  defp tool_to_function(%Lens{name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: name || "unnamed_lens",
        description: description || "",
        parameters: schema
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
        model: body["model"],
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
      _ ->
        {:error, "Failed to parse Perplexity response: #{inspect(body)}"}
    end
  end

  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} -> {:ok, structured_output}
      {:error, _} -> {:ok, content}
    end
  end

  def parse_content(nil), do: {:ok, nil}
  def parse_content(_other), do: {:ok, nil}

  def execute_tool_calls(nil), do: {:ok, nil}
  def execute_tool_calls([]), do: {:ok, []}

  def execute_tool_calls(tool_calls) when is_list(tool_calls) do
    results =
      Enum.map(tool_calls, fn
        %{"function" => %{"name" => name, "arguments" => args}} ->
          case Jason.decode(args) do
            {:ok, decoded_args} -> {name, decoded_args}
            {:error, _} -> {name, args}
          end
      end)

    {:ok, results}
  end

  defp handle_error(error) do
    Logger.error("Perplexity AI API error: #{inspect(error)}")
    {:error, "Perplexity AI API error: #{inspect(error)}"}
  end

  @doc """
  Returns the list of available Perplexity models with their pricing.
  """
  def models do
    [
      %{
        id: "sonar",
        name: "Sonar",
        description: "Fast, cost-effective web-augmented model",
        input_price_per_1m: 1.00,
        output_price_per_1m: 1.00,
        max_tokens: 128_000,
        online: true
      },
      %{
        id: "sonar-pro",
        name: "Sonar Pro",
        description: "Enhanced web-augmented model with better reasoning",
        input_price_per_1m: 3.00,
        output_price_per_1m: 15.00,
        max_tokens: 200_000,
        online: true
      },
      %{
        id: "sonar-deep-research",
        name: "Sonar Deep Research",
        description: "Reasoning-heavy model for complex research tasks",
        input_price_per_1m: 5.00,
        output_price_per_1m: 15.00,
        max_tokens: 128_000,
        online: true
      }
    ]
  end

  @doc """
  Estimate the cost of a request based on model and token counts.
  """
  def estimate_cost(model, input_tokens, output_tokens) do
    pricing = model_pricing(model)

    case pricing do
      {:ok, %{input_price_per_1m: input_price, output_price_per_1m: output_price}} ->
        round_cost(input_price * input_tokens / 1_000_000 + output_price * output_tokens / 1_000_000)

      :error ->
        0.0
    end
  end

  @doc """
  Calculate cost from a usage map returned by the API.
  """
  def cost_from_usage(usage) when is_map(usage) do
    model = Map.get(usage, "model", "sonar")
    input_tokens = Map.get(usage, "prompt_tokens", 0)
    output_tokens = Map.get(usage, "completion_tokens", 0)

    %{
      cost: estimate_cost(model, input_tokens, output_tokens),
      model: model,
      input_tokens: input_tokens,
      output_tokens: output_tokens
    }
  end

  defp round_cost(cost), do: Float.round(cost, 6)

  defp model_pricing("sonar") do
    {:ok, %{input_price_per_1m: 1.00, output_price_per_1m: 1.00}}
  end

  defp model_pricing("sonar-pro") do
    {:ok, %{input_price_per_1m: 3.00, output_price_per_1m: 15.00}}
  end

  defp model_pricing("sonar-deep-research") do
    {:ok, %{input_price_per_1m: 5.00, output_price_per_1m: 15.00}}
  end

  defp model_pricing(_), do: :error
end
