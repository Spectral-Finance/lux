defmodule Lux.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation for local, self-hosted models.
  Supports passing Beams, Prisms, and Lenses as tools.
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @endpoint "http://localhost:11434/api/chat"

  defmodule Config do
    @moduledoc """
    Configuration module for Ollama.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            temperature: float(),
            top_p: float(),
            top_k: integer(),
            num_predict: integer() | nil,
            stop: list(String.t()),
            seed: integer() | nil,
            num_ctx: integer(),
            repeat_penalty: float(),
            messages: [map()]
          }

    defstruct endpoint: "http://localhost:11434/api/chat",
              model: "llama3",
              temperature: 0.7,
              top_p: 0.9,
              top_k: 40,
              num_predict: nil,
              stop: [],
              seed: nil,
              num_ctx: 4096,
              repeat_penalty: 1.1,
              messages: []
  end

  @impl true
  def call(prompt, tools, config) do
    config = struct(Config, Map.merge(%{model: Application.get_env(:lux, :ollama_models)[:default]}, config))

    messages = config.messages ++ [%{role: "user", content: prompt}]

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        stream: false,
        options: %{
          temperature: config.temperature,
          top_p: config.top_p,
          top_k: config.top_k,
          num_predict: config.num_predict,
          stop: config.stop,
          seed: config.seed,
          num_ctx: config.num_ctx,
          repeat_penalty: config.repeat_penalty
        }
      }
      |> then(fn b -> if tools != [], do: Map.put(b, :tools, Enum.map(tools, &tool_to_function/1)), else: b end)

    [
      url: config.endpoint,
      json: remove_nils(body),
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = r} -> handle_response(r)
      {:ok, %{status: 401}} -> {:error, :invalid_api_key}
      {:ok, %{status: s, body: %{"error" => m}}} -> {:error, {s, m}}
      {:error, %{reason: :econnrefused}} -> {:error, "Cannot connect to Ollama at " <> config.endpoint}
      {:error, e} -> {:error, inspect(e)}
    end
  end

  defp handle_response(%{body: body}) do
    with %{"message" => msg} <- body,
         {:ok, content} <- (if is_binary(msg["content"]), do: {:ok, msg["content"]}, else: {:ok, nil}),
         {:ok, tool_results} <- (if msg["tool_calls"], do: execute_tool_calls(msg["tool_calls"]), else: {:ok, nil}) do
      %{schema_id: ResponseSignal, payload: %{content: content, model: body["model"], finish_reason: body["done_reason"], tool_calls: msg["tool_calls"], tool_calls_results: tool_results}, metadata: %{total_duration: body["total_duration"], eval_count: body["eval_count"]}}
      |> Lux.Signal.new()
      |> ResponseSignal.validate()
    end
  end

  defp execute_tool_calls(tool_calls) do
    Enum.reduce_while(tool_calls, {:ok, []}, fn tc, {:ok, acc} ->
      case execute_tool_call(tc) do
        {:ok, r} -> {:cont, {:ok, [r | acc]}}
        e -> {:halt, e}
      end
    end)
  end

  defp execute_tool_call(%{"function" => %{"name" => n, "arguments" => a}}) do
    args = Jason.decode!(a)
    mod = n |> String.replace("_", ".") |> Module.concat()
    cond do
      Lux.prism?(mod) -> mod.handler(args, nil)
      Lux.beam?(mod) -> mod.run(args, nil)
      true -> {:error, "Tool not found: " <> n}
    end
  end

  defp tool_to_function({:python, path}), do: path |> Prism.view() |> tool_to_function()
  defp tool_to_function(%Beam{name: n, description: d, input_schema: s}), do: %{type: "function", function: %{name: String.replace(n, ".", "_"), description: d || "", parameters: s}}
  defp tool_to_function(%Prism{module_name: n, description: d, input_schema: s}), do: %{type: "function", function: %{name: String.replace(n, ".", "_"), description: d || "", parameters: s}}
  defp tool_to_function(%Lens{name: n, description: d, schema: s}), do: %{type: "function", function: %{name: n || "lens", description: d || "", parameters: s}}

  defp remove_nils(map), do: map |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()
end
