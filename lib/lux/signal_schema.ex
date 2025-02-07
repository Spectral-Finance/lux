defmodule Lux.SignalSchema do
  @moduledoc """
  Defines the behavior and macros for creating Signal schemas.

  Signal schemas define the structure and validation rules for Signal content.
  They are used to ensure that Signals conform to expected formats and can be
  properly processed by agents and workflows.
  """

  alias Lux.UUID

  require Logger

  @type compatibility :: :full | :backward | :forward | :none
  @type format :: :json | :yaml | :binary | :text
  @type status :: :draft | :active | :deprecated | :retired

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          version: String.t(),
          schema: map(),
          created_at: DateTime.t(),
          created_by: String.t(),
          description: String.t() | nil,
          tags: [String.t()],
          compatibility: compatibility(),
          status: status(),
          format: format(),
          reference: String.t() | nil
        }

  defstruct [
    :id,
    :name,
    :version,
    :schema,
    :created_at,
    :created_by,
    :description,
    tags: [],
    compatibility: :full,
    status: :draft,
    format: :json,
    reference: nil
  ]

  @doc """
  Creates a new schema struct from the given attributes.
  """
  def new(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> Map.put_new_lazy(:id, &UUID.generate/0)
      |> Map.put_new_lazy(:created_at, &DateTime.utc_now/0)

    struct!(__MODULE__, attrs)
  end

  @callback validate(map(), any()) :: {:ok, Lux.Signal.t()} | {:error, any()}

  @doc """
  Defines a new Signal schema.

  ## Options
    * `:name` - The name of the schema. Defaults to the module name if not provided.
    * `:version` - The schema version. Defaults to "1.0.0".
    * `:schema` - Required. The JSON Schema definition for the Signal content.
    * `:description` - Optional description of the schema.
    * `:tags` - Optional list of tags for categorization.
    * `:compatibility` - Schema compatibility level (:full, :backward, :forward, :none).
    * `:status` - Schema status (:draft, :active, :deprecated, :retired).
    * `:format` - Data format (:json, :yaml, :binary, :text).
    * `:reference` - Optional reference to external schema documentation.
  """
  defmacro __using__(opts) do
    quote do
      @schema_name unquote(opts[:name])
      @schema_description unquote(opts[:description])
      @schema_version unquote(opts[:version])
      @schema_tags unquote(opts[:tags])
      @schema_compatibility unquote(opts[:compatibility])
      @schema_format unquote(opts[:format])
      @normalized_schema Lux.SignalSchema.normalize(unquote(opts)[:schema])
      @compiled_schema ExJsonSchema.Schema.resolve(@normalized_schema)

      @schema_struct %Lux.SignalSchema{
        id: UUID.generate(),
        name: @schema_name || __MODULE__ |> Module.split() |> List.last(),
        description: @schema_description || nil,
        version: @schema_version || nil,
        tags: @schema_tags || [],
        compatibility: @schema_compatibility || :full,
        format: @schema_format || :json,
        schema: @normalized_schema
      }

      def name, do: @schema_struct.name
      def schema, do: @schema_struct.schema
      def schema_id, do: @schema_struct.id
      def view, do: @schema_struct
      def id, do: @schema_struct.id

      # check if the module implements the validate function, otherwise use the default implementation
      if not function_exported?(__MODULE__, :validate, 1) do
        def validate(signal), do: Lux.SignalSchema.validate(signal, @compiled_schema)
      end

      defoverridable validate: 1
    end
  end

  @doc """
  Recursively converts all map keys to strings in a schema definition.
  """
  def normalize(map) when is_map(map) do
    Map.new(map, fn
      {key, value} -> {to_string(key), normalize(value)}
    end)
  end

  def normalize([]), do: []

  def normalize([head | tail]) do
    [normalize(head) | normalize(tail)]
  end

  def normalize(nil), do: nil
  def normalize(value) when is_boolean(value), do: value
  def normalize(value) when is_atom(value), do: to_string(value)
  def normalize(value), do: value

  def validate(signal, schema) do
    case ExJsonSchema.Validator.validate(schema, normalize(signal.payload)) do
      :ok -> {:ok, signal}
      {:error, error} -> {:error, error}
    end
  end
end
