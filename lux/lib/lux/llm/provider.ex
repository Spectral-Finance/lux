defmodule Lux.LLM.Provider do
  @moduledoc """
  Core behaviour module defining the universal provider interface.

  All LLM providers (OpenAI, Anthropic, local models, etc.) must implement
  this behaviour to ensure a consistent interface across the system.

  ## Callbacks

  Providers must implement:

  - `complete/2` - Synchronous completion request
  - `stream/2` - Streaming completion request (returns a Stream)
  - `health_check/1` - Verify provider connectivity and authentication
  - `list_models/1` - List available models for this provider
  - `name/0` - Return the provider's unique identifier
  - `default_config/0` - Return default configuration for this provider

  ## Example

      defmodule MyApp.LLM.Providers.Custom do
        @behaviour Lux.LLM.Provider

        @impl true
        def name, do: :custom

        @impl true
        def default_config do
          %{: base_url => "https://api.custom.com", timeout => 30_000}
        end

        @impl true
        def complete(request, config) do
          # Implementation
        end

        # ... other callbacks
      end
  """

  # === Core Types ===

  @type provider_name :: atom()

  @type model_id :: String.t()

  @type provider_config :: %{
          name: provider_name(),
          api_key: String.t() | nil,
          base_url: String.t() | nil,
          timeout: pos_integer(),
          max_retries: non_neg_integer(),
          models: [model_config()],
          metadata: map()
        }

  @type model_config :: %{
          id: model_id(),
          name: String.t(),
          capabilities: [capability()],
          context_window: pos_integer(),
          max_output_tokens: pos_integer(),
          cost_per_input_token: float(),
          cost_per_output_token: float(),
          supports_streaming: boolean(),
          supports_functions: boolean(),
          supports_vision: boolean()
        }

  @type capability ::
          :chat
          | :completion
          | :embedding
          | :image_generation
          | :function_calling
          | :vision
          | :code

  # === Request/Response Types ===

  @type message :: %{
          role: :system | :user | :assistant | :function,
          content: String.t() | [content_part()],
          name: String.t() | nil,
          function_call: map() | nil
        }

  @type content_part ::
          %{type: :text, text: String.t()}
          | %{type: :image_url, image_url: %{url: String.t()}}

  @type completion_request :: %{
          messages: [message()],
          model: model_id() | nil,
          temperature: float() | nil,
          max_tokens: pos_integer() | nil,
          stream: boolean(),
          functions: [function_def()] | nil,
          function_call: :auto | :none | %{name: String.t()} | nil,
          stop: [String.t()] | nil,
          metadata: map()
        }

  @type function_def :: %{
          name: String.t(),
          description: String.t(),
          parameters: map()
        }

  @type completion_response :: %{
          id: String.t(),
          provider: provider_name(),
          model: model_id(),
          choices: [choice()],
          usage: usage_info(),
          created_at: DateTime.t(),
          metadata: map()
        }

  @type choice :: %{
          index: non_neg_integer(),
          message: message(),
          finish_reason: :stop | :length | :function_call | :content_filter | nil
        }

  @type usage_info :: %{
          prompt_tokens: non_neg_integer(),
          completion_tokens: non_neg_integer(),
          total_tokens: non_neg_integer()
        }

  @type stream_chunk :: %{
          id: String.t(),
          provider: provider_name(),
          model: model_id(),
          delta: delta(),
          finish_reason: :stop | :length | :function_call | :content_filter | nil,
          created_at: DateTime.t()
        }

  @type delta :: %{
          role: :system | :user | :assistant | :function | nil,
          content: String.t() | nil,
          function_call: map() | nil
        }

  @type health_status :: %{
          healthy: boolean(),
          latency_ms: non_neg_integer() | nil,
          message: String.t() | nil,
          checked_at: DateTime.t()
        }

  @type provider_error ::
          :authentication_failed
          | :rate_limited
          | :model_not_found
          | :context_length_exceeded
          | :content_filtered
          | :timeout
          | :network_error
          | :server_error
          | :invalid_request
          | :unknown_error

  @type error_response :: %{
          error: provider_error(),
          message: String.t(),
          retryable: boolean(),
          retry_after_ms: non_neg_integer() | nil
        }

  # === Callbacks ===

  @doc """
  Returns the unique identifier for this provider.

  ## Examples

      iex> MyProvider.name()
      :openai
  """
  @callback name() :: provider_name()

  @doc """
  Returns the default configuration for this provider.

  This configuration can be overridden by user-provided settings.

  ## Examples

      iex> MyProvider.default_config()
      %{base_url: "https://api.openai.com/v1", timeout: 30_000, max_retries: 3}
  """
  @callback default_config() :: map()

  @doc """
  Performs a synchronous completion request.

  ## Parameters

  - `request` - The completion request containing messages and options
  - `config` - Provider configuration including API keys and settings

  ## Returns

  - `{:ok, response}` - Successful completion response
  - `{:error, error_response}` - Error with details

  ## Examples

      iex> request = %{messages: [%{role: :user, content: "Hello!"}]}
      iex> MyProvider.complete(request, config)
      {:ok, %{id: "...", choices: [...], usage: %[...]}}
  """
  @callback complete(request :: completion_request(), config :: provider_config()) ::
              {:ok, completion_response()} | {:error, error_response()}

  @doc """
  Performs a streaming completion request.

  Returns an enumerable stream of chunks that can be processed incrementally.

  ## Parameters

  - `request` - The completion request (stream field is ignored, always streams)
  - `config` - Provider configuration

  ## Returns

  - `{:ok, stream}` - An Enumerable.t() of stream_chunk()
  - `{:error, error_response}` - Error with details

  ## Examples

      iex> request = %{messages: [%{role: :user, content: "Tell me a story"}]}
      iex> {:ok, stream} = MyProvider.stream(request, config)
      iex> Enum.each(stream, fn chunk -> IO.write(chunk.delta.content) end)
  """
  @callback stream(request :: completion_request(), config :: provider_config()) ::
              {:ok, Enumerable.t(stream_chunk())} | {:error, error_response()}

  @doc """
  Performs a health check on the provider.

  Verifies connectivity, authentication, and basic API functionality.

  ## Parameters

  - `config` - Provider configuration to test

  ## Returns

  - `{:ok, health_status}` - Health check results

  ## Examples

      iex> MyProvider.health_check(config)
      {:ok, %{healthy: true, latency_ms: 123, checked_at: ~2024-01-15 ...}}
  """
  @callback health_check(config :: provider_config()) :: {:ok, health_status()}

  @doc """
  Lists all available models for this provider.

  ## Parameters

  - `config` - Provider configuration

  ## Returns

  - `{:ok, [model_config]}` - List of available models with their configurations
  - `{:error, error_response}` - Error if unable to fetch models

  ## Examples

      iex> MyProvider.list_models(config)
      {:ok, [
        %{id: "gpt-4", name: "GPT-4", capabilities: [:chat, :function_calling]},
        ...
      ]}
  """
  @callback list_models(config :: provider_config()) ::
              {:ok, [model_config()]} | {:error, error_response()}

  # === Optional Callbacks ===

  @doc """
  Validates a completion request before sending to the provider.

  This is an optional callback that allows providers to perform
  provider-specific validation.

  ## Returns

  - `:ok` - Request is valid
  - `{:error, reason}` - Request is invalid
  """
  @callback validate_request(request :: completion_request(), config :: provider_config()) ::
              :ok | {:error, String.t()}

  @doc """
  Estimates the token count for a given text or message list.

  This is an optional callback for providers that can estimate tokens
  without making an API call.

  ## Returns

  - `{:ok, token_count}` - Estimated number of tokens
  - `{:error, reason}` - Unable to estimate
  """
  @callback estimate_tokens(input :: String.t() | [message()], model :: model_id()) ::
              {:ok, non_neg_integer()} | {:error, String.t()}

  @optional_callbacks validate_request: 2, estimate_tokens: 2

  # === Helper Functions ===

  @doc """
  Builds a standardized error response.

  ## Parameters

  - `error` - The error type atom
  - `message` - Human-readable error message
  - `opts` - Optional keyword list with `:retryable` and `:retry_after_ms`

  ## Returns

  An error_response map.

  ## Examples

      iex> Lux.LLM.Provider.build_error(:rate_limited, "Too many requests", retry_after_ms: 60000)
      %{error: :rate_limited, message: "Too many requests", retryable: true, retry_after_ms: 60000}
  """
  @spec build_error(provider_error(), String.t(), Keyword.t()) :: error_response()
  def build_error(error, message, opts \\ []) do
    retryable = Keyword.get(opts, :retryable, retryable_error?(error))
    retry_after_ms = Keyword.get(opts, :retry_after_ms)

    %{
      error: error,
      message: message,
      retryable: retryable,
      retry_after_ms: retry_after_ms
    }
  end

  @doc """
  Builds a standardized completion response.

  ## Parameters

  - `attrs` - Map of response attributes

  ## Returns

  A completion_response map.
  """
  @spec build_response(map()) :: completion_response()
  def build_response(attrs) do
    %{
      id: Map.get(attrs, :id, generate_id()),
      provider: Map.fetch!(attrs, :provider),
      model: Map.fetch!(attrs, :model),
      choices: Map.fetch!(attrs, :choices),
      usage: Map.get(attrs, :usage, %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}),
      created_at: Map.get(attrs, :created_at, DateTime.utc_now()),
      metadata: Map.get(attrs, :metadata, %{})
    }
  end

  @doc """
  Builds a standardized stream chunk.

  ## Parameters

  - `attrs` - Map of chunk attributes

  ## Returns

  A stream_chunk map.
  """
  @spec build_stream_chunk(map()) :: stream_chunk()
  def build_stream_chunk(attrs) do
    %{
      id: Map.get(attrs, :id, generate_id()),
      provider: Map.fetch!(attrs, :provider),
      model: Map.fetch!(attrs, :model),
      delta: Map.get(attrs, :delta, %{role: nil, content: nil, function_call: nil}),
      finish_reason: Map.get(attrs, :finish_reason),
      created_at: Map.get(attrs, :created_at, DateTime.utc_now())
    }
  end

  @doc """
  Builds a standardized health status response.

  ## Parameters

  - `healthy` - Whether the provider is healthy
  - `opts` - Optional keyword list with `:latency_ms` and `:message`

  ## Returns

  A health_status map.
  """
  @spec build_health_status(boolean(), Keyword.t()) :: health_status()
  def build_health_status(healthy, opts \\ []) do
    %{
      healthy: healthy,
      latency_ms: Keyword.get(opts, :latency_ms),
      message: Keyword.get(opts, :message),
      checked_at: DateTime.utc_now()
    }
  end

  @doc """
  Determines if an error type is retryable by default.

  ## Parameters

  - `error` - The error type atom

  ## Returns

  `true` if the error is typically retryable, `false` otherwise.

  ## Examples

      iex> Lux.LLM.Provider.retryable_error?(:rate_limited)
      true

      iex> Lux.LLM.Provider.retryable_error?(:authentication_failed)
      false
  """
  @spec retryable_error?(provider_error()) :: boolean()
  def retryable_error?(:rate_limited), do: true
  def retryable_error?(:timeout), do: true
  def retryable_error?(:network_error), do: true
  def retryable_error?(:server_error), do: true
  def retryable_error?(_), do: false

  @doc """
  Generates a unique ID for responses.

  ## Returns

  A UUID string.
  """
  @spec generate_id() :: String.t()
  def generate_id do
    <<a1::32, a2::16, a3::16, a4::16, a5::48>> = :crypto.strong_rand_bytes(16)

    :io_lib.format("~8.16.0b~~4.16.0b~~4.16.0b~~4.16.0b~~12.16.0b", [a1, a2, a3, a4, a5])
    |> IO.iodata_to_binary()
  end

  @doc """
  Normalizes a completion request with default values.

  ## Parameters

  - `request` - The raw request map

  ## Returns

  A normalized completion_request map with default values filled in.
  """
  @spec normalize_request(map()) :: completion_request()
  def normalize_request(request) do
    %{
      messages: Map.get(request, :messages, []) |> normalize_messages(),
      model: Map.get(request, :model),
      temperature: Map.get(request, :temperature),
      max_tokens: Map.get(request, :max_tokens),
      stream: Map.get(request, :stream, false),
      functions: Map.get(request, :functions),
      function_call: Map.get(request, :function_call),
      stop: Map.get(request, :stop),
      metadata: Map.get(request, :metadata, %{})
    }
  end

  @doc """
  Normalizes a list of messages to ensure consistent structure.

  ## Parameters

  - `messages` - List of message maps

  ## Returns

  A list of normalized message maps.
  """
  @spec normalize_messages([map()]) :: [message()]
  def normalize_messages(messages) do
    Enum.map(messages, &normalize_message/1)
  end

  @doc false
  @spec normalize_message(map()) :: message()
  def normalize_message(message) do
    role =
      case Map.get(message, :role) do
        r when is/atom(r) -> r
        r when is_binary(r) -> String.to_existing_atom(r)
        _ -> :user
      end

    %{
      role: role,
      content: Map.get(message, :content, ""),
      name: Map.get(message, :name),
      function_call: Map.get(message, :function_call)
    }
  end
end