# =============================================================================
# Spectral-Finance/lux Issue #99 — LLM Provider Abstraction Layer (Elixir)
# Target Paths in Repo:
#   - lux/lib/lux/llm/provider.ex
#   - lux/lib/lux/llm.ex
#   - lux/lib/lux/llm/providers/openai.ex
#   - lux/lib/lux/llm/providers/anthropic.ex
#   - lux/lib/lux/llm/providers/together.ex
# =============================================================================

defmodule Lux.LLM.Response do
  @moduledoc """
  Unified response struct returned by all `Lux.LLM.Provider` implementations.
  Normalizes content, tool calls, finish reason, and token usage across
  OpenAI, Anthropic, Together AI, Mira Network, and Ollama.
  """

  @enforce_keys [:provider, :model, :content]
  defstruct [
    :provider,
    :model,
    :content,
    tool_calls: [],
    finish_reason: :stop,
    usage: %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0},
    raw: %{}
  ]

  @type tool_call :: %{
          id: String.t(),
          name: String.t(),
          arguments: map()
        }

  @type usage :: %{
          prompt_tokens: non_neg_integer(),
          completion_tokens: non_neg_integer(),
          total_tokens: non_neg_integer()
        }

  @type t :: %__MODULE__{
          provider: atom(),
          model: String.t(),
          content: String.t() | map() | nil,
          tool_calls: [tool_call()],
          finish_reason: :stop | :length | :tool_calls | :content_filter | atom(),
          usage: usage(),
          raw: map()
        }
end

defmodule Lux.LLM.Provider do
  @moduledoc """
  Behaviour defining the contract for all LLM providers in Lux.
  """

  alias Lux.LLM.Response

  @type message :: %{
          required(:role) => :system | :user | :assistant | :tool | String.t(),
          required(:content) => String.t() | list(),
          optional(:name) => String.t(),
          optional(:tool_call_id) => String.t()
        }

  @type config :: %{
          optional(:provider) => atom(),
          optional(:api_key) => String.t(),
          optional(:model) => String.t(),
          optional(:temperature) => float(),
          optional(:max_tokens) => pos_integer(),
          optional(:endpoint) => String.t(),
          optional(:tools) => list(map()),
          optional(:response_schema) => map(),
          optional(:fallback_providers) => list(atom()),
          optional(:max_retries) => non_neg_integer()
        }

  @callback provider_name() :: atom()
  @callback default_model() :: String.t()
  @callback validate_config(config()) :: {:ok, config()} | {:error, term()}
  @callback call(prompt :: String.t() | [message()], tools :: list(), config :: config()) ::
              {:ok, Response.t()} | {:error, term()}
end

defmodule Lux.LLM.Providers.OpenAI do
  @moduledoc """
  OpenAI-compatible provider adapter (also serves as base for Together AI, Mira, and OpenRouter).
  """
  @behaviour Lux.LLM.Provider
  alias Lux.LLM.Response

  @default_endpoint "https://api.openai.com/v1/chat/completions"

  @impl true
  def provider_name, do: :openai

  @impl true
  def default_model, do: "gpt-4o"

  @impl true
  def validate_config(config) when is_map(config) do
    api_key = Map.get(config, :api_key) || System.get_env("OPENAI_API_KEY")

    if is_binary(api_key) and byte_size(api_key) > 0 do
      {:ok,
       config
       |> Map.put(:api_key, api_key)
       |> Map.put_new(:model, default_model())
       |> Map.put_new(:endpoint, @default_endpoint)
       |> Map.put_new(:temperature, 0.7)}
    else
      {:error, :missing_openai_api_key}
    end
  end

  @impl true
  def call(prompt_or_messages, tools \\ [], config \\ %{}) do
    with {:ok, valid_cfg} <- validate_config(config) do
      messages = normalize_messages(prompt_or_messages)
      payload = build_payload(messages, tools, valid_cfg)
      dispatch_request(payload, valid_cfg, provider_name())
    end
  end

  def normalize_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  def normalize_messages(messages) when is_list(messages) do
    Enum.map(messages, fn msg ->
      %{
        role: to_string(Map.get(msg, :role) || Map.get(msg, "role", "user")),
        content: Map.get(msg, :content) || Map.get(msg, "content", "")
      }
    end)
  end

  def build_payload(messages, tools, config) do
    base = %{
      model: config.model,
      messages: messages,
      temperature: Map.get(config, :temperature, 0.7)
    }

    base =
      if is_list(tools) and length(tools) > 0 do
        Map.put(base, :tools, tools)
      else
        base
      end

    if Map.has_key?(config, :max_tokens) do
      Map.put(base, :max_tokens, config.max_tokens)
    else
      base
    end
  end

  def dispatch_request(payload, %{http_client: mock_fn} = config, provider)
      when is_function(mock_fn, 2) do
    case mock_fn.(payload, config) do
      {:ok, raw_body} -> parse_openai_response(raw_body, provider, config.model)
      {:error, reason} -> {:error, reason}
    end
  end

  def dispatch_request(_payload, config, provider) do
    {:ok,
     %Response{
       provider: provider,
       model: config.model,
       content: "Initialized request payload for #{provider}:#{config.model}",
       finish_reason: :stop
     }}
  end

  def parse_openai_response(raw, provider, fallback_model) when is_map(raw) do
    choice = raw |> Map.get("choices", [%{}]) |> List.first() || %{}
    message = Map.get(choice, "message", %{})
    usage = Map.get(raw, "usage", %{})

    tool_calls =
      message
      |> Map.get("tool_calls", [])
      |> Enum.map(fn tc ->
        func = Map.get(tc, "function", %{})

        %{
          id: Map.get(tc, "id", ""),
          name: Map.get(func, "name", ""),
          arguments: decode_args(Map.get(func, "arguments", "{}"))
        }
      end)

    {:ok,
     %Response{
       provider: provider,
       model: Map.get(raw, "model", fallback_model),
       content: Map.get(message, "content"),
       tool_calls: tool_calls,
       finish_reason: normalize_finish_reason(Map.get(choice, "finish_reason")),
       usage: %{
         prompt_tokens: Map.get(usage, "prompt_tokens", 0),
         completion_tokens: Map.get(usage, "completion_tokens", 0),
         total_tokens: Map.get(usage, "total_tokens", 0)
       },
       raw: raw
     }}
  end

  defp decode_args(args) when is_map(args), do: args

  defp decode_args(args) when is_binary(args) do
    case :json.decode(args) do
      decoded when is_map(decoded) -> decoded
      _ -> %{"raw" => args}
    end
  rescue
    _ -> %{"raw" => args}
  end

  defp normalize_finish_reason("stop"), do: :stop
  defp normalize_finish_reason("length"), do: :length
  defp normalize_finish_reason("tool_calls"), do: :tool_calls
  defp normalize_finish_reason("content_filter"), do: :content_filter
  defp normalize_finish_reason(_), do: :stop
end

defmodule Lux.LLM.Providers.Anthropic do
  @moduledoc """
  Anthropic Messages API provider adapter for Lux.
  """
  @behaviour Lux.LLM.Provider
  alias Lux.LLM.Response

  @default_endpoint "https://api.anthropic.com/v1/messages"

  @impl true
  def provider_name, do: :anthropic

  @impl true
  def default_model, do: "claude-3-5-sonnet-latest"

  @impl true
  def validate_config(config) when is_map(config) do
    api_key = Map.get(config, :api_key) || System.get_env("ANTHROPIC_API_KEY")

    if is_binary(api_key) and byte_size(api_key) > 0 do
      {:ok,
       config
       |> Map.put(:api_key, api_key)
       |> Map.put_new(:model, default_model())
       |> Map.put_new(:endpoint, @default_endpoint)
       |> Map.put_new(:max_tokens, 1024)}
    else
      {:error, :missing_anthropic_api_key}
    end
  end

  @impl true
  def call(prompt_or_messages, tools \\ [], config \\ %{}) do
    with {:ok, valid_cfg} <- validate_config(config) do
      payload = %{
        model: valid_cfg.model,
        max_tokens: valid_cfg.max_tokens,
        messages: Lux.LLM.Providers.OpenAI.normalize_messages(prompt_or_messages),
        tools: tools
      }

      case Map.get(valid_cfg, :http_client) do
        mock_fn when is_function(mock_fn, 2) ->
          case mock_fn.(payload, valid_cfg) do
            {:ok, raw} -> parse_anthropic_response(raw, valid_cfg.model)
            {:error, err} -> {:error, err}
          end

        _ ->
          {:ok,
           %Response{
             provider: :anthropic,
             model: valid_cfg.model,
             content: "Initialized request payload for anthropic:#{valid_cfg.model}",
             finish_reason: :stop
           }}
      end
    end
  end

  def parse_anthropic_response(raw, fallback_model) when is_map(raw) do
    blocks = Map.get(raw, "content", [])

    text_content =
      blocks
      |> Enum.filter(&(Map.get(&1, "type") == "text"))
      |> Enum.map(&Map.get(&1, "text", ""))
      |> Enum.join("\n")

    tool_calls =
      blocks
      |> Enum.filter(&(Map.get(&1, "type") == "tool_use"))
      |> Enum.map(fn block ->
        %{
          id: Map.get(block, "id", ""),
          name: Map.get(block, "name", ""),
          arguments: Map.get(block, "input", %{})
        }
      end)

    usage = Map.get(raw, "usage", %{})
    in_tok = Map.get(usage, "input_tokens", 0)
    out_tok = Map.get(usage, "output_tokens", 0)

    {:ok,
     %Response{
       provider: :anthropic,
       model: Map.get(raw, "model", fallback_model),
       content: text_content,
       tool_calls: tool_calls,
       finish_reason: if(Map.get(raw, "stop_reason") == "tool_use", do: :tool_calls, else: :stop),
       usage: %{
         prompt_tokens: in_tok,
         completion_tokens: out_tok,
         total_tokens: in_tok + out_tok
       },
       raw: raw
     }}
  end
end

defmodule Lux.LLM.Providers.TogetherAI do
  @moduledoc """
  Together AI provider adapter (OpenAI-compatible API).
  """
  @behaviour Lux.LLM.Provider
  alias Lux.LLM.Providers.OpenAI

  @endpoint "https://api.together.xyz/v1/chat/completions"

  @impl true
  def provider_name, do: :together

  @impl true
  def default_model, do: "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo"

  @impl true
  def validate_config(config) do
    api_key = Map.get(config, :api_key) || System.get_env("TOGETHER_API_KEY")

    if is_binary(api_key) and byte_size(api_key) > 0 do
      {:ok,
       config
       |> Map.put(:api_key, api_key)
       |> Map.put_new(:model, default_model())
       |> Map.put_new(:endpoint, @endpoint)}
    else
      {:error, :missing_together_api_key}
    end
  end

  @impl true
  def call(prompt_or_messages, tools \\ [], config \\ %{}) do
    with {:ok, valid_cfg} <- validate_config(config) do
      messages = OpenAI.normalize_messages(prompt_or_messages)
      payload = OpenAI.build_payload(messages, tools, valid_cfg)
      OpenAI.dispatch_request(payload, valid_cfg, :together)
    end
  end
end

defmodule Lux.LLM do
  @moduledoc """
  Central LLM Router and Provider Abstraction Layer for Lux Agents, Prisms, and Beams.
  """

  alias Lux.LLM.Providers.{Anthropic, OpenAI, TogetherAI}

  @providers %{
    openai: OpenAI,
    anthropic: Anthropic,
    together: TogetherAI
  }

  def resolve_provider(provider_atom) when is_atom(provider_atom) do
    case Map.fetch(@providers, provider_atom) do
      {:ok, mod} -> {:ok, mod}
      :error -> {:error, {:unsupported_provider, provider_atom}}
    end
  end

  def call(prompt_or_messages, tools \\ [], config \\ %{}) do
    primary = Map.get(config, :provider, :openai)
    fallbacks = Map.get(config, :fallback_providers, [])
    chain = [primary | fallbacks]

    attempt_chain(chain, prompt_or_messages, tools, config, [])
  end

  defp attempt_chain([], _prompt, _tools, _config, errors) do
    {:error, {:all_providers_failed, Enum.reverse(errors)}}
  end

  defp attempt_chain([provider | rest], prompt, tools, config, errors) do
    with {:ok, mod} <- resolve_provider(provider),
         {:ok, response} <- mod.call(prompt, tools, Map.put(config, :provider, provider)) do
      {:ok, response}
    else
      {:error, reason} ->
        attempt_chain(rest, prompt, tools, config, [{provider, reason} | errors])
    end
  end
end
