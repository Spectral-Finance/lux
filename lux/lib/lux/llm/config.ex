defmodule Lux.LLM.Config do
  @moduledoc """
  Configuration management for LLM providers.

  This module provides functions for:

  - Building and validating provider configurations
  - Handling environment variables for API keys
  - Providing sensible defaults for provider settings
  - Merging user-provided configs with defaults

  ## Example

      iex> Lux.LLM.Config.build(:openai, api_key: "sk-...")
      {:ok, %{name: :openai, api_key: "sk-...", ...}}

      iex> Lux.LLM.Config.build(:openai)  # Uses OPENAI_API_KEY env var
      {:ok, %{name: :openai, api_key: "sk-...", ...}}

  """

  # === Core Types ===
  @type provider_name :: atom()
  @type model_id :: String.t()

  @type capability ::
          :chat
          | :completion
          | :embedding
          | :image_generation
          | :function_calling
          | :vision
          | :code

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

  @type provider_config :: %{
          name: provider_name(),
          api_key: String.t() | nil,
          base_url: String.t() | nil,
          timeout: pos_integer(),
          max_retries: non_neg_integer(),
          models: [model_config()],
          metadata: map()
        }

  @type config_option ::
          {:api_key, String.t()}
          | {:base_url, String.t()}
          | {:timeout, pos_integer()}
          | {:max_retries, non_neg_integer()}
          | {:models, [model_config()]}
          | {:metadata, map()}

  # Default values
  @default_timeout 30_000
  @default_max_retries 3

  # Provider-specific defaults
  @provider_defaults %{
    openai: %{
      base_url: "https://api.openai.com/v1",
      env_key: "OPENAI_API_KEY"
    },
    anthropic: %{
      base_url: "https://api.anthropic.com/v1",
      env_key: "ANTHROPIC_API_KEY"
    },
    local: %{
      base_url: "http://localhost:11434",
      env_key: nil
    }
  }

  @doc """
  Builds a provider configuration with validation.

  Accepts a provider name and optional configuration options.
  Will automatically load API keys from environment variables
  if not explicitly provided.

  ## Options

  - `:api_key` - API key for the provider (optional, falls back to env var)
  - `:base_url` - Base URL for API requests (optional, uses provider default)
  - `:timeout` - Request timeout in milliseconds (default: 30_000)
  - `:max_retries` - Maximum retry attempts (default: 3)
  - `:models` - List of model configurations (default: [])
  - `:metadata` - Additional metadata (default: %{})

  ## Examples

      iex> Lux.LLM.Config.build(:openai, api_key: "sk-test123")
      {:ok, %{name: :openai, api_key: "sk-test123", ...}}

      iex> Lux.LLM.Config.build(:unknown)
      {:error, :unknown_provider}

  """
  @spec build(provider_name(), [config_option()]) ::
          {:ok, provider_config()} | {:error, atom() | String.t()}
  def build(provider_name, opts \\ []) do
    with {:ok, defaults} <- get_provider_defaults(provider_name),
         {:ok, api_key} <- resolve_api_key(opts, defaults),
         {:ok, config} <- build_config(provider_name, api_key, defaults, opts),
         {:ok, validated} <- validate_config(config) do
      {:ok, validated}
    end
  end

  @doc """
  Builds a provider configuration, raising on error.

  Same as `build/2` but raises an exception instead of returning an error tuple.

  ## Examples

      iex> Lux.LLM.Config.build!(:openai, api_key: "sk-test123")
      %{name: :openai, api_key: "sk-test123", ...}

  """
  @spec build!(provider_name(), [config_option()]) :: provider_config()
  def build!(provider_name, opts \\ []) do
    case build(provider_name, opts) do
      {:ok, config} -> config
      {:error, reason} -> raise ArgumentError, "Failed to build config: #{inspect(reason)}"
    end
  end

  @doc """
  Validates an existing provider configuration.

  Checks that all required fields are present and have valid values.

  ## Examples

      iex> Lux.LLM.Config.validate(%{name: :openai, api_key: "sk-...", ...})
      {:ok, %{name: :openai, ...}}

      iex> Lux.LLM.Config.validate(%{})
      {:error, :missing_name}

  """
  @spec validate(map()) :: {:ok, provider_config()} | {:error, atom()}
  def validate(config) when is_map(config) do
    validate_config(config)
  end

  @doc """
  Merges two configurations, with the second taking precedence.

  Useful for overriding default configurations with request-specific options.

  ## Examples

      iex> base = %{name: :openai, timeout: 30_000, metadata: %{}}
      iex> overrides = %{timeout: 60_000}
      iex> Lux.LLM.Config.merge(base, overrides)
      %{name: :openai, timeout: 60_000, metadata: %{}}

  """
  @spec merge(provider_config(), map()) :: provider_config()
  def merge(base_config, overrides) when is_map(base_config) and is_map(overrides) do
    base_config
    |> Map.merge(overrides)
    |> merge_metadata(base_config, overrides)
  end

  @doc """
  Gets an API key from an environment variable.

  ## Examples

      iex> System.put_env("TEST_API_KEY", "test-key")
      iex> Lux.LLM.Config.get_env_key("TEST_API_KEY")
      {:ok, "test-key"}

      iex> Lux.LLM.Config.get_env_key("NONEXISTENT_KEY")
      {:error, :env_not_set}

  """
  @spec get_env_key(String.t()) :: {:ok, String.t()} | {:error, :env_not_set}
  def get_env_key(env_var_name) when is_binary(env_var_name) do
    case System.get_env(env_var_name) do
      nil -> {:error, :env_not_set}
      "" -> {:error, :env_not_set}
      value -> {:ok, value}
    end
  end

  @doc """
  Returns the list of supported provider names.

  ## Examples

      iex> Lux.LLM.Config.supported_providers()
      [:openai, :anthropic, :local]

  """
  @spec supported_providers() :: [provider_name()]
  def supported_providers do
    Map.keys(@provider_defaults)
  end

  @doc """
  Checks if a provider is supported.

  ## Examples

      iex> Lux.LLM.Config.provider_supported?(:openai)
      true

      iex> Lux.LLM.Config.provider_supported?(:unknown)
      false

  """
  @spec provider_supported?(provider_name()) :: boolean()
  def provider_supported?(provider_name) do
    Map.has_key?(@provider_defaults, provider_name)
  end

  @doc """
  Returns the default base URL for a provider.

  ## Examples

      iex> Lux.LLM.Config.default_base_url(:openai)
      {:ok, "https://api.openai.com/v1"}

      iex> Lux.LLM.Config.default_base_url(:unknown)
      {:error, :unknown_provider}

  """
  @spec default_base_url(provider_name()) :: {:ok, String.t()} | {:error, :unknown_provider}
  def default_base_url(provider_name) do
    case Map.get(@provider_defaults, provider_name) do
      nil -> {:error, :unknown_provider}
      %{:base_url => base_url} -> {:ok, base_url}
    end
  end

  # Private functions

  @spec get_provider_defaults(provider_name()) :: {:ok, map()} | {:error, :unknown_provider}
  defp get_provider_defaults(provider_name) do
    case Map.get(@provider_defaults, provider_name) do
      nil -> {:error, :unknown_provider}
      defaults -> {:ok, defaults}
    end
  end

  @spec resolve_api_key(keyword(), map()) :: {:ok, String.t() | nil}
  defp resolve_api_key(opts, defaults) do
    case Keyword.get(opts, :api_key) do
      nil ->
        # Try to get from environment variable
        case Map.get(defaults, :env_key) do
          nil -> {:ok, nil}
          env_key ->
            case get_env_key(env_key) do
              {:ok, key} -> {:ok, key}
              {:error, :env_not_set} -> {:ok, nil}
            end
        end

      api_key when is_binary(api_key) ->
        {:ok, api_key}
    end
  end

  @spec build_config(provider_name(), String.t() | nil, map(), keyword()) ::
          {:ok, provider_config()}
  defp build_config(provider_name, api_key, defaults, opts) do
    config = %{
      name: provider_name,
      api_key: api_key,
      base_url: Keyword.get(opts, :base_url, Map.get(defaults, :base_url)),
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      max_retries: Keyword.get(opts, :max_retries, @default_max_retries),
      models: Keyword.get(opts, :models, []),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    {:ok, config}
  end

  @spec validate_config(map()) :: {:ok, provider_config()} | {:error, atom()}
  defp validate_config(config) do
    with :ok <- validate_name(config),
         :ok <- validate_timeout(config),
         :ok <- validate_max_retries(config),
         :ok <- validate_models(config) do
      {:ok, config}
    end
  end

  @spec validate_name(map()) :: :ok | {:error, :missing_name | :invalid_name}
  defp validate_name(config) do
    case Map.get(config, :name) do
      nil -> {:error, :missing_name}
      name when is_atom(name) -> :ok
      _ -> {:error, :invalid_name}
    end
  end

  @spec validate_timeout(map()) :: :ok | {:error, :invalid_timeout}
  defp validate_timeout(config) do
    case Map.get(config, :timeout) do
      timeout when is_integer(timeout) and timeout > 0 -> :ok
      _ -> {:error, :invalid_timeout}
    end
  end

  @spec validate_max_retries(map()) :: :ok | {:error, :invalid_max_retries}
  defp validate_max_retries(config) do
    case Map.get(config, :max_retries) do
      retries when is_integer(retries) and retries >= 0 -> :ok
      _ -> {:error, :invalid_max_retries}
    end
  end

  @spec validate_models(map()) :: :ok | {:error, :invalid_models}
  defp validate_models(config) do
    case Map.get(config, :models) do
      models when is_list(models) -> :ok
      _ -> {:error, :invalid_models}
    end
  end

  @spec merge_metadata(map(), map(), map()) :: map()
  defp merge_metadata(merged, base_config, overrides) do
    base_metadata = Map.get(base_config, :metadata, %{})
    override_metadata = Map.get(overrides, :metadata, %{})

    Map.put(merged, :metadata, Map.merge(base_metadata, override_metadata))
  end
end