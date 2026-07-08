defmodule Lux.Agent.Config do
  @moduledoc """
  Standardized configuration structure for Lux agents.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          goal: String.t(),
          module: module() | String.t(),
          template: atom(),
          template_opts: map(),
          prisms: list(),
          beams: list(),
          lenses: list(),
          signal_handlers: list(),
          llm_config: map()
        }

  defstruct [
    :id,
    :name,
    :description,
    :goal,
    :module,
    template: :default,
    template_opts: %{},
    prisms: [],
    beams: [],
    lenses: [],
    signal_handlers: [],
    llm_config: %{}
  ]

  @doc """
  Creates a new Config struct from a map of attributes.
  """
  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    config = struct(__MODULE__, atomize_keys(attrs))

    case validate(config) do
      :ok -> {:ok, config}
      error -> error
    end
  end

  @doc """
  Validates a configuration struct.
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = config) do
    with :ok <- validate_required_fields(config) do
      validate_types(config)
    end
  end

  defp validate_required_fields(config) do
    required = [:id, :name, :description, :goal, :module]
    missing = Enum.filter(required, &is_nil(Map.get(config, &1)))

    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_types(%{id: id}) when not is_binary(id),
    do: {:error, {:invalid_type, :id, :string}}

  defp validate_types(%{name: name}) when not is_binary(name),
    do: {:error, {:invalid_type, :name, :string}}

  defp validate_types(%{description: desc}) when not is_binary(desc),
    do: {:error, {:invalid_type, :description, :string}}

  defp validate_types(%{goal: goal}) when not is_binary(goal),
    do: {:error, {:invalid_type, :goal, :string}}

  defp validate_types(%{module: mod}) when not is_atom(mod) and not is_binary(mod),
    do: {:error, {:invalid_type, :module, :module_name}}

  defp validate_types(_), do: :ok

  # Private helper functions

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_atom(k), atomize_value(v, k)} end)
  end

  # Handle special fields that should be atoms
  defp atomize_value(value, key) when key in ["template", :template] and is_binary(value) do
    String.to_atom(value)
  end

  # Handle nested maps that should preserve string keys
  defp atomize_value(value, key)
       when key in ["template_opts", :template_opts, "llm_config", :llm_config] and is_map(value) do
    Map.new(value, fn {k, v} -> {k, preserve_string_keys(v)} end)
  end

  # Default handlers
  defp atomize_value(value, _key) when is_map(value), do: atomize_keys(value)

  defp atomize_value(value, _key) when is_list(value),
    do: Enum.map(value, &atomize_value(&1, nil))

  defp atomize_value(value, _key), do: value

  defp to_atom(key) when is_atom(key), do: key
  defp to_atom(key) when is_binary(key), do: String.to_atom(key)

  # Helper to preserve string keys in nested maps
  defp preserve_string_keys(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {k, preserve_string_keys(v)} end)
  end

  defp preserve_string_keys(value) when is_list(value) do
    Enum.map(value, &preserve_string_keys/1)
  end

  defp preserve_string_keys(value), do: value
end
