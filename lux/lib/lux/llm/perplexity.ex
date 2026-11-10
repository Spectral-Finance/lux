defmodule Lux.LLM.Perplexity do
  @moduledoc """
  Perplexity AI LLM implementation that supports passing Beams, Prisms, and Lenses as tools.

  Perplexity AI exposes an OpenAI-compatible chat-completions endpoint which
  additionally supports real-time web-search augmented responses via its `sonar`
  model family.

  ## Configuration

  The following keys are accepted in the third argument of `call/3`:

    * `:api_key`          - Perplexity API key (defaults to `Application.get_env(:lux, :api_keys)[:perplexity]`)
    * `:model`            - Model name (defaults to `Application.get_env(:lux, :perplexity_models)[:default]`, fallback `"sonar"`)
    * `:endpoint`         - Base URL (defaults to `"https://api.perplexity.ai/chat/completions"`)
    * `:temperature`      - Sampling temperature 0.0–2.0 (default `0.7`)
    * `:max_tokens`       - Maximum completion tokens (default `nil`, i.e. model decides)
    * `:top_p`            - Nucleus sampling (default `1.0`)
    * `:top_k`            - Top-k sampling (default `0` = disabled)
    * `:presence_penalty` - Presence penalty -2.0–2.0 (default `0.0`)
    * `:frequency_penalty`- Frequency penalty >=0 (default `1.0`)
    * `:return_citations` - Return inline citations (default `false`)
    * `:return_images`    - Return images in response (default `false`)
    * `:return_related_questions` - Return related questions (default `false`)
    * `:search_domain_filter`     - Allowlist of domains for search (default `nil`)
    * `:search_recency_filter`    - Recency filter: `"month"`, `"week"`, `"day"`, `"hour"` (default `nil`)
    * `:receive_timeout`  - HTTP receive timeout in ms (default `60_000`)
    * `:messages`         - Pre-pended conversation history (default `[]`)

  ## Example

      Lux.LLM.Perplexity.call(
        "What is the capital of France?",
        [],
        %{
          api_key: "pplx-...",
          model: "sonar",
          return_citations: true
        }
      )
  """

  @behaviour Lux.LLM

  alias Lux.Beam
  alias Lux.Lens
  alias Lux.Prism

  require Beam
  require Lens
  require Logger

  @endpoint "https://api.perplexity.ai/chat/completions"

  defmodule Config do
    @moduledoc """
    Configuration struct for `Lux.LLM.Perplexity`.

    All fields can be overridden by the `options` map passed to `call/3`.
    """

    @type t :: %__MODULE__{
            endpoint: String.t(),
            model: String.t(),
            api_key: String.t() | nil,
            temperature: float(),
            max_tokens: integer() | nil,
            top_p: float(),
            top_k: integer(),
            presence_penalty: float(),
            frequency_penalty: float(),
            return_citations: boolean(),
            return_images: boolean(),
            return_related_questions: boolean(),
            search_domain_filter: [String.t()] | nil,
            search_recency_filter: String.t() | nil,
            receive_timeout: integer(),
            messages: [map()]
          }

    defstruct endpoint: "https://api.perplexity.ai/chat/completions",
              model: "sonar",
              api_key: nil,
              temperature: 0.7,
              max_tokens: nil,
              top_p: 1.0,
              top_k: 0,
              presence_penalty: 0.0,
              frequency_penalty: 1.0,
              return_citations: false,
              return_images: false,
              return_related_questions: false,
              search_domain_filter: nil,
              search_recency_filter: nil,
              receive_timeout: 60_000,
              messages: []
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @impl true
  def call(prompt, tools, options) when is_map(options) or is_list(options) do
    config = build_config(options)
    messages = config.messages ++ build_messages(prompt)
    tools_config = build_tools_config(tools)

    body =
      %{
        model: Lux.Config.resolve(config.model),
        messages: messages,
        temperature: config.temperature,
        top_p: config.top_p,
        top_k: config.top_k,
        presence_penalty: config.presence_penalty,
        frequency_penalty: config.frequency_penalty,
        return_citations: config.return_citations,
        return_images: config.return_images,
        return_related_questions: config.return_related_questions
      }
      |> maybe_add_max_tokens(config)
      |> maybe_add_search_domain_filter(config)
      |> maybe_add_search_recency_filter(config)
      |> maybe_add_tools(tools_config)

    [
      url: config.endpoint,
      json: body,
      headers: [
        {"Authorization", "Bearer #{Lux.Config.resolve(config.api_key)}"},
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ],
      receive_timeout: config.receive_timeout
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.post()
    |> handle_http_result()
  end

  # ---------------------------------------------------------------------------
  # Config helpers
  # ---------------------------------------------------------------------------

  defp build_config(options) do
    defaults = %{
      model: Application.get_env(:lux, :perplexity_models)[:default] || "sonar",
      api_key: Application.get_env(:lux, :api_keys)[:perplexity]
    }

    struct(Config, Map.merge(defaults, normalize_options(options)))
  end

  defp normalize_options(opts) when is_list(opts), do: Map.new(opts)
  defp normalize_options(opts) when is_map(opts), do: opts

  # ---------------------------------------------------------------------------
  # Message building
  # ---------------------------------------------------------------------------

  defp build_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp build_messages(messages) when is_list(messages) do
    Enum.map(messages, fn
      %{role: _role, content: _content} = msg -> msg
      msg when is_binary(msg) -> %{role: "user", content: msg}
    end)
  end

  # ---------------------------------------------------------------------------
  # Tool building (OpenAI-compatible function-calling format)
  # ---------------------------------------------------------------------------

  defp build_tools_config([]), do: []
  defp build_tools_config(tools), do: Enum.map(tools, &tool_to_function/1)

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools), do: Map.put(body, :tools, tools)

  @doc false
  def tool_to_function({:python, path}) do
    path
    |> Prism.view()
    |> tool_to_function()
  end

  @doc false
  def tool_to_function(tool_module) when is_atom(tool_module) and not is_nil(tool_module) do
    cond do
      Lux.prism?(tool_module) -> tool_to_function(tool_module.view())
      Lux.beam?(tool_module) -> tool_to_function(tool_module.view())
      Lux.lens?(tool_module) -> tool_to_function(tool_module.view())
      true -> raise "Unsupported tool type: #{inspect(tool_module)}"
    end
  end

  @doc false
  def tool_to_function(%Beam{module_name: name, description: desc, input_schema: schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: desc || "",
        parameters: schema
      }
    }
  end

  @doc false
  def tool_to_function(%Prism{module_name: name, description: desc, input_schema: schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: desc || "",
        parameters: schema
      }
    }
  end

  @doc false
  def tool_to_function(%Lens{module_name: name, description: desc, schema: schema}) do
    %{
      type: "function",
      function: %{
        name: String.replace(name, ".", "_"),
        description: desc || "",
        parameters: schema
      }
    }
  end

  # ---------------------------------------------------------------------------
  # Optional body fields
  # ---------------------------------------------------------------------------

  defp maybe_add_max_tokens(body, %Config{max_tokens: nil}), do: body
  defp maybe_add_max_tokens(body, %Config{max_tokens: n}), do: Map.put(body, :max_tokens, n)

  defp maybe_add_search_domain_filter(body, %Config{search_domain_filter: nil}), do: body

  defp maybe_add_search_domain_filter(body, %Config{search_domain_filter: domains})
       when is_list(domains),
       do: Map.put(body, :search_domain_filter, domains)

  defp maybe_add_search_recency_filter(body, %Config{search_recency_filter: nil}), do: body

  defp maybe_add_search_recency_filter(body, %Config{search_recency_filter: filter})
       when filter in ["month", "week", "day", "hour"],
       do: Map.put(body, :search_recency_filter, filter)

  defp maybe_add_search_recency_filter(body, _config), do: body

  # ---------------------------------------------------------------------------
  # HTTP response handling
  # ---------------------------------------------------------------------------

  defp handle_http_result({:ok, %{status: 200} = response}), do: handle_success(response)
  defp handle_http_result({:ok, %{status: 401}}), do: {:error, :invalid_api_key}
  defp handle_http_result({:ok, %{status: 403}}), do: {:error, :forbidden}

  defp handle_http_result({:ok, %{status: status, body: %{"error" => %{"message" => msg}}}}) do
    {:error, {status, msg}}
  end

  defp handle_http_result({:ok, %{status: status, body: body}}) do
    {:error, {status, inspect(body)}}
  end

  defp handle_http_result({:error, reason}) do
    Logger.error("Perplexity API error: #{inspect(reason)}")
    {:error, "Perplexity API error: #{inspect(reason)}"}
  end

  # ---------------------------------------------------------------------------
  # Success response parsing
  # ---------------------------------------------------------------------------

  defp handle_success(%{body: body}) do
    with %{"choices" => [choice | _]} <- body,
         %{"message" => message, "finish_reason" => finish_reason} <- choice,
         {:ok, content} <- parse_content(message["content"]),
         {:ok, tool_calls} <- parse_tool_calls(message["tool_calls"]) do
      response = %Lux.LLM.Response{
        content: content,
        tool_calls: tool_calls,
        finish_reason: finish_reason,
        structured_output: build_structured_output(body)
      }

      {:ok, response}
    else
      unexpected ->
        {:error, "Unexpected Perplexity response format: #{inspect(unexpected)}"}
    end
  end

  # Build a structured output map that includes Perplexity-specific extras
  defp build_structured_output(body) do
    %{
      model: body["model"],
      citations: body["citations"],
      images: body["images"],
      related_questions: body["related_questions"],
      usage: body["usage"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc false
  def parse_content(nil), do: {:ok, nil}

  def parse_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:ok, content}
    end
  end

  defp parse_tool_calls(nil), do: {:ok, []}
  defp parse_tool_calls([]), do: {:ok, []}

  defp parse_tool_calls(tool_calls) when is_list(tool_calls) do
    parsed =
      Enum.map(tool_calls, fn %{"function" => %{"name" => name, "arguments" => args}} ->
        decoded_args =
          case Jason.decode(args) do
            {:ok, map} -> map
            {:error, _} -> args
          end

        %{type: "function", name: name, params: decoded_args}
      end)

    {:ok, parsed}
  end
end
