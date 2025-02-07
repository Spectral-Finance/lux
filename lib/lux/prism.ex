defmodule Lux.Prism do
  @moduledoc """
  Modular, composable units of functionality for defining actions.

  Prisms are used to define actions that can be executed by agents.

  ## Example

      defmodule MyApp.Prisms.WeatherPrism do
        use Lux.Prism,
          name: "Weather Data",
          description: "Fetches weather data for a given location",
          input_schema: %{
            type: :object,
            properties: %{
              location: %{type: :string, description: "City name"},
              units: %{type: :string, description: "Temperature units (C/F)"}
            }
          }

        def handler(input, _ctx) do
          # Implementation
        end
      end

  """
  use Lux.Types

  @typedoc """
  A schema is either a map of key-value pairs that describe the structure of the data,
  or a module that implements the Lux.SignalSchema behaviour.
  """
  @type schema :: map() | module()

  @typedoc """
  A handler is a function or a module that handles the data.
  """
  @type handler :: function() | mfa() | binary()

  @typedoc """
  A validator is a function or a module that validates the data.
  """
  @type validator :: function() | mfa() | binary()

  defstruct [
    :id,
    :name,
    :handler,
    :description,
    :examples,
    :input_schema,
    :output_schema
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          handler: handler(),
          description: nullable(String.t()),
          examples: nullable([String.t()]),
          input_schema: nullable(schema()),
          output_schema: nullable(schema())
        }

  @doc """
  Creates a new prism from a map or keyword list.
  """
  @spec new(map() | keyword()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      id: attrs[:id] || "",
      name: attrs[:name] || "",
      handler: attrs[:handler] || nil,
      description: attrs[:description] || "",
      examples: attrs[:examples] || [],
      input_schema: resolve_schema(attrs[:input_schema]),
      output_schema: resolve_schema(attrs[:output_schema])
    }
  end

  def new(attrs) when is_list(attrs) do
    attrs |> Map.new() |> new()
  end

  @doc """
  A handler is the function that will be called when the prism is executed.
  """
  @callback handler(input :: any(), context :: any()) :: {:ok, any()} | {:error, any()}

  defmacro __using__(opts) do
    quote do
      @behaviour Lux.Prism

      alias Lux.Prism

      # Register compile-time attributes
      Module.register_attribute(__MODULE__, :prism_config, persist: false)
      Module.register_attribute(__MODULE__, :prism_struct, persist: false)

      # Store the configuration at compile time
      @prism_config %{
        name: Keyword.get(unquote(opts), :name, __MODULE__ |> Module.split() |> List.last()),
        description: Keyword.get(unquote(opts), :description, ""),
        input_schema: Keyword.get(unquote(opts), :input_schema),
        output_schema: Keyword.get(unquote(opts), :output_schema),
        examples: Keyword.get(unquote(opts), :examples, []),
        id: Keyword.get(unquote(opts), :id, Lux.UUID.generate())
      }

      # Create the struct at compile time
      @prism_struct Lux.Prism.new(
                      id: Lux.UUID.generate(),
                      name: @prism_config.name,
                      description: @prism_config.description,
                      input_schema: @prism_config.input_schema,
                      output_schema: @prism_config.output_schema,
                      examples: @prism_config.examples
                    )

      def run(input, context \\ nil) do
        Lux.Prism.run(__MODULE__, input, context)
      end

      @doc """
      Returns the Prism struct for this module.
      """
      def view do
        %{@prism_struct | handler: &__MODULE__.handler/2}
      end

      defoverridable run: 2
    end
  end

  def run(schema, input, context \\ nil)

  def run(module, input, context) when is_atom(module) do
    module.handler(input, context)
  end

  def run(%__MODULE__{handler: handler}, input, context) do
    handler.(input, context)
  end

  @optional_callbacks []

  @doc """
  Resolves a schema reference to its actual schema definition.
  If the schema is a module that implements Lux.SignalSchema, returns its schema.
  Otherwise, returns the schema as is.
  """
  def resolve_schema(schema) when is_atom(schema) do
    if function_exported?(schema, :schema, 0) do
      schema.schema()
    else
      schema
    end
  end

  def resolve_schema(schema), do: schema
end
