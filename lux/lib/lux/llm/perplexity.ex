defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI LLM implementation for online web research, citations, and multi-step reasoning.

  Features:
  - Implements the `Lux.LLM` behaviour.
  - Native conversion and execution of Beams, Prisms, and Lenses as LLM tools.
  - Web search domain filtering (`search_domain_filter`) and recency limits (`search_recency_filter`).
  - Structured citations extraction and markdown footnote formatting.
  - Token and search request cost estimation (`Lux.LLM.Perplexity.ModelRouter`).
  - Exponential backoff retry handling for rate limits and upstream transient errors.
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.LLM.Perplexity.Citations
  alias Lux.LLM.Perplexity.ModelRouter
  alias Lux.LLM.ResponseSignal
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @default_endpoint "https://api.perplexity.ai/chat/completions"
  @default_model "sonar-pro"

  defmodule Config do
    @moduledoc """
    Configuration struct for Perplexity AI requests.
    """
    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t() | nil,
            temperature: float(),
            top_p: float(),
            top_k: integer() | nil,
            max_tokens: integer() | nil,
            presence_penalty: float() | nil,
            frequency_penalty: float() | nil,
            search_domain_filter: list(String.t()),
            search_recency_filter: String.t() | nil,
            return_citations: boolean(),
            return_images: boolean(),
            return_related_questions: boolean(),
            messages: list(map()),
            max_retries: non_neg_integer(),
            retry_backoff_ms: non_neg_integer()
          }

    defstruct endpoint: "https://api.perplexity.ai/chat/completions",
              model: "sonar-pro",
              api_key: nil,
              temperature: 0.2,
              top_p: 0.9,
              top_k: nil,
              max_tokens: nil,
              presence_penalty: nil,
              frequency_penalty: nil,
              search_domain_filter: [],
              search_recency_filter: nil,
              return_citations: true,
              return_images: false,
              return_related_questions: false,
              messages: [],
              max_retries: 3,
              retry_backoff_ms: 500
  end

  @impl true
  def call(prompt, tools, config) do
    config = build_config(config)

    case validate_api_key(config.api_key) do
      {:ok, api_key} ->
        config = %{config | api_key: api_key}
        messages = config.messages ++ build_messages(prompt)
        tools_config = build_tools_config(tools)

        body =
          %{
            model: Lux.Config.resolve(config.model),
            messages: messages,
            temperature: config.temperature,
            top_p: config.top_p,
            return_citations: config.return_citations,
            return_images: config.return_images,
            return_related_questions: config.return_related_questions
          }
          |> maybe_add(:max_tokens, config.max_tokens)
          |> maybe_add(:top_k, config.top_k)
          |> maybe_add(:presence_penalty, config.presence_penalty)
          |> maybe_add(:frequency_penalty, config.frequency_penalty)
          |> maybe_add(:search_domain_filter, (config.search_domain_filter != [] && config.search_domain_filter) || nil)
          |> maybe_add(:search_recency_filter, config.search_recency_filter)
          |> maybe_add_tools(tools_config)

        headers = [
          {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
          {"Content-Type", "application/json"}
        ]

        req_opts =
          [
            url: config.endpoint,
            json: body,
            headers: headers
          ]
          |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

        execute_with_retries(req_opts, config.max_retries, config.retry_backoff_ms, config)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Runs direct search chat completion.
  """
  def chat(prompt, opts \\ []) do
    config = Map.new(opts)
    call(prompt, [], config)
  end

  @doc """
  Runs deep reasoning with `sonar-reasoning-pro`.
  """
  def reason(prompt, opts \\ []) do
    config =
      opts
      |> Keyword.put_new(:model, "sonar-reasoning-pro")
      |> Map.new()

    call(prompt, [], config)
  end

  # Helpers
  defp build_config(config) when is_map(config) do
    default_model =
      case Application.get_env(:lux, :perplexity_models) do
        models when is_list(models) -> Keyword.get(models, :default, @default_model)
        _ -> @default_model
      end

    default_key =
      case Application.get_env(:lux, :api_keys) do
        keys when is_list(keys) -> Keyword.get(keys, :perplexity)
        keys when is_map(keys) -> Map.get(keys, :perplexity)
        _ -> nil
      end || System.get_env("PERPLEXITY_API_KEY")

    struct(
      Config,
      Map.merge(
        %{
          model: default_model,
          api_key: default_key,
          endpoint: @default_endpoint
        },
        config
      )
    )
  end
  defp build_config(config) when is_list(config), do: build_config(Map.new(config))

  defp validate_api_key(nil), do: {:error, :missing_api_key}
  defp validate_api_key(""), do: {:error, :missing_api_key}
  defp validate_api_key("missing perplexity"), do: {:error, :missing_api_key}
  defp validate_api_key(key) when is_binary(key), do: {:ok, key}

  defp build_messages(prompt) when is_binary(prompt), do: [%{role: "user", content: prompt}]
  defp build_messages(messages) when is_list(messages), do: messages
  defp build_messages(_), do: []

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, val), do: Map.put(map, key, val)

  # Tool mappings
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

  def tool_to_function(%Beam{name: name, description: description, input_schema: input_schema}) do
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

  def tool_to_function(%Lens{name: name, description: description, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: name || "unnamed_lens",
        description: description || "",
        parameters: schema
      }
    }
  end

  # Execution & Retries
  defp execute_with_retries(req_opts, retries_left, backoff_ms, config) do
    req_opts
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200} = response} ->
        handle_response(response, config)

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: 429, body: body}} when retries_left > 0 ->
        Logger.warning("Perplexity rate limited (429). Retrying in #{backoff_ms}ms... Body: #{inspect(body)}")
        :timer.sleep(backoff_ms)
        execute_with_retries(req_opts, retries_left - 1, backoff_ms * 2, config)

      {:ok, %{status: status, body: body}} when status in [502, 503, 504] and retries_left > 0 ->
        Logger.warning("Perplexity server error (#{status}). Retrying in #{backoff_ms}ms... Body: #{inspect(body)}")
        :timer.sleep(backoff_ms)
        execute_with_retries(req_opts, retries_left - 1, backoff_ms * 2, config)

      {:ok, %{status: status, body: %{"error" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} when retries_left > 0 ->
        Logger.warning("Perplexity network error: #{inspect(reason)}. Retrying in #{backoff_ms}ms...")
        :timer.sleep(backoff_ms)
        execute_with_retries(req_opts, retries_left - 1, backoff_ms * 2, config)

      {:error, reason} ->
        Logger.error("Perplexity request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Response Parsing
  defp handle_response(%{body: body}, _config) do
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

      raw_citations = body["citations"] || []
      parsed_citations = Citations.parse_citations(raw_citations)
      usage = body["usage"] || %{}
      prompt_tokens = usage["prompt_tokens"] || 0
      completion_tokens = usage["completion_tokens"] || 0
      model_id = body["model"] || "sonar-pro"

      cost_estimate = ModelRouter.estimate_cost(model_id, prompt_tokens, completion_tokens, 1)

      metadata = %{
        id: body["id"],
        created: body["created"],
        usage: usage,
        citations: raw_citations,
        parsed_citations: parsed_citations,
        cost_estimate: cost_estimate
      }

      %{
        schema_id: ResponseSignal,
        payload: payload,
        metadata: metadata
      }
      |> Lux.Signal.new()
      |> ResponseSignal.validate()
    else
      nil ->
        {:error, "Invalid Perplexity response: missing choices"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_content(nil), do: {:ok, nil}
  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, structured_output} -> {:ok, structured_output}
      {:error, _} -> {:ok, content}
    end
  end
  def parse_content(other), do: {:ok, other}

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
    parsed_args =
      case args do
        str when is_binary(str) ->
          case Jason.decode(str) do
            {:ok, m} -> m
            _ -> %{}
          end
        m when is_map(m) -> m
        _ -> %{}
      end

    execute_tool(tool_name, parsed_args, nil)
  end
  def execute_tool_call(_), do: {:ok, nil}

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
        {:error, "Failed to load tool module #{tool_name}: module not found"}

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

      true ->
        {:error, "Tool #{tool_module} is not a valid Beam or Prism"}
    end
  end
end
