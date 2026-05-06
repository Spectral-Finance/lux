defmodule Lux.LLM.Mira do
  @moduledoc """
  Mira Network LLM implementation that supports passing Beams, Prisms, and Lenses as tools.
  """

  
  @behaviour Lux.LLM.Provider

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @endpoint "https://api.mira.network/v1/chat/completions"

  defmodule Config do
    @moduledoc """
    Configuration module for Mira Network.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t(),
            temperature: float(),
            max_tokens: integer(),
            stream: boolean(),
            messages: [map()]
          }

    defstruct endpoint: "https://api.mira.network/v1/chat/completions",
              model: "llama-3.1-8b-instruct",
              api_key: nil,
              temperature: 0.7,
              max_tokens: nil,
              stream: false,
              messages: []
  end

  # ──────────────────────────────────────
  # Lux.LLM.Provider callbacks
  # ──────────────────────────────────────

  @impl Lux.LLM.Provider
  def models do
    [
      "llama-3.1-8b-instruct",
      "llama-3.1-70b-instruct",
      "llama-3.1-405b-instruct",
      "mixtral-8x7b-instruct",
      "mixtral-8x22b-instruct"
    ]
  end

  @impl Lux.LLM.Provider
  def models(criteria) do
    supported = models()

    Enum.reduce(criteria, supported, fn
      {:capability, :tools}, acc ->
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
  def cost("llama-3.1-8b-instruct"), do: {:ok, %{model: "llama-3.1-8b-instruct", input_per_1k_tokens: 0.0002, output_per_1k_tokens: 0.0002, currency: "USD"}}
  def cost("llama-3.1-70b-instruct"), do: {:ok, %{model: "llama-3.1-70b-instruct", input_per_1k_tokens: 0.0007, output_per_1k_tokens: 0.0009, currency: "USD"}}
  def cost("llama-3.1-405b-instruct"), do: {:ok, %{model: "llama-3.1-405b-instruct", input_per_1k_tokens: 0.002, output_per_1k_tokens: 0.0025, currency: "USD"}}
  def cost("mixtral-8x7b-instruct"), do: {:ok, %{model: "mixtral-8x7b-instruct", input_per_1k_tokens: 0.0005, output_per_1k_tokens: 0.0005, currency: "USD"}}
  def cost("mixtral-8x22b-instruct"), do: {:ok, %{model: "mixtral-8x22b-instruct", input_per_1k_tokens: 0.001, output_per_1k_tokens: 0.001, currency: "USD"}}
  def cost(_), do: {:error, :unknown_model}

  @impl Lux.LLM.Provider
  def capabilities do
    [:chat, :tools, :streaming]
  end

  @impl Lux.LLM.Provider
  def default_config do
    %Config{}
  end

  @impl Lux.LLM.Provider
  def metadata do
    %{
      name: "Mira Network",
      module: __MODULE__,
      description: "Mira Network open-source models",
      models: models(),
      capabilities: capabilities(),
      cost_per_1k_input_tokens: 0.0002,
      cost_per_1k_output_tokens: 0.0002,
      priority: 4,
      enabled: true,
      tags: ["mira", "open-source", "llama", "mixtral"]
    }
  end

  # ──────────────────────────────────────
  # Lux.LLM callbacks
  # ──────────────────────────────────────

  @impl true
  def call(prompt, tools, config) do
    config = struct(Config, config)

    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        temperature: config.temperature,
        max_tokens: config.max_tokens,
        stream: config.stream
      }
      |> maybe_add_tools(tools_config)

    [
      url: config.endpoint,
      json: body,
      headers: [
        {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
        {"Content-Type", "application/json"},
        {"Accept", "*/*"}
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

      {:ok, %{status: 403}} ->
        {:error, :not_authenticated}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: %{"detail" => detail}}} ->
        {:error, {status, detail}}

      {:error, error} ->
        handle_error(error)
    end
  end

  defp build_messages(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body

  defp maybe_add_tools(body, tools) do
    body
    |> Map.put(:tools, tools)
  end

  defp tool_to_function(%Beam{module_name: name, description: description, input_schema: input_schema}) do
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

  defp tool_to_function(%Lens{module_name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: description || "",
        parameters: schema
      }
    }
  end

  defp handle_response(%{body: body}, _config) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> handle_response(%{body: decoded}, _config)
      {:error, _} -> {:error, "Failed to decode response body"}
    end
  end

  defp handle_response(%{body: %{"data" => data}}, _config) do
    with %{
           "choices" => [choice | _],
           "usage" => usage,
           "id" => id,
           "created" => created
         } <- data,
         %{"message" => message, "finish_reason" => finish_reason} <- choice,
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls_results} <- execute_tool_calls(message["tool_calls"]) do
      payload = %{
        content: content,
        model: data["model"],
        finish_reason: finish_reason,
        tool_calls: message["tool_calls"],
        tool_calls_results: tool_calls_results
      }

      metadata = %{
        id: id,
        created: created,
        usage: usage,
        system_fingerprint: data["system_fingerprint"]
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
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:ok, %{"text" => content}}
    end
  end

  defp execute_tool_calls(nil), do: {:ok, nil}
  defp execute_tool_calls([]), do: {:ok, []}

  defp execute_tool_calls(tool_calls) when is_list(tool_calls) do
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
    Logger.error("Error calling Mira Network API: #{inspect(error)}")
    {:error, "Failed to call Mira Network API"}
  end
end
