defmodule Lux.Rust.Component do
  @moduledoc """
  Define Lux components (Prisms, Beams, Lenses) in Rust.

  This module provides the Elixir-side API for defining and interacting
  with Rust-native components. Rust components are defined using traits
  and are registered in a BTreeMap-based registry.

  ## Component Types

  - **Prism** — synchronous pipeline component with handler(input) -> output
  - **Beam** — workflow component with execute(input) -> results
  - **Lens** — data-fetching component

  ## Usage

      Lux.Rust.Component.define(:prism, "MyPrism",
        handler: "fn process(input) { ... }",
        schema: %{input: :string, output: :string}
      )

      result = Lux.Rust.Component.execute(:prism, "MyPrism", "some input")
  """

  @type component_type :: :prism | :beam | :lens

  @type component_definition :: %{
          name: String.t(),
          kind: String.t(),
          handler: String.t(),
          schema: map(),
          metadata: map()
        }

  @doc """
  Defines a new Rust component and registers it.

  ## Parameters

    * `type` — `:prism`, `:beam`, or `:lens`
    * `name` — unique component name
    * `opts` — definition options

  ## Options

    * `:handler` — Rust handler code (required for prisms)
    * `:execute` — Rust execute code (required for beams)
    * `:schema` — input/output schema
    * `:description` — human-readable description
    * `:version` — component version string

  ## Returns

    * `{:ok, component_id}` — component registered successfully
    * `{:error, reason}` — registration failed
  """
  @spec define(component_type(), String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def define(type, name, opts \\ []) do
    kind = type_string(type)
    handler = Keyword.get(opts, :handler)
    execute = Keyword.get(opts, :execute)
    schema = Keyword.get(opts, :schema, %{})
    description = Keyword.get(opts, :description, "")
    version = Keyword.get(opts, :version, "0.1.0")

    case validate_definition(kind, handler, execute) do
      :ok ->
        def_json =
          %{
            name: name,
            kind: kind,
            handler: handler,
            execute: execute,
            schema: schema,
            description: description,
            version: version
          }
          |> Jason.encode!()

        if Lux.Native.loaded?() do
          case Lux.Native.rust_register_component(def_json) do
            true -> {:ok, "#{kind}:#{name}"}
            false -> {:error, "Component '#{name}' already registered"}
          end
        else
          {:error, "Rust native library not loaded"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Executes a registered Rust component.

  ## Parameters

    * `type` — component type (`:prism`, `:beam`, `:lens`)
    * `name` — component name
    * `input` — input data to pass to the component

  ## Returns

    * `{:ok, result}` — component executed successfully
    * `{:error, reason}` — execution failed
  """
  @spec execute(component_type(), String.t(), term()) :: {:ok, term()} | {:error, String.t()}
  def execute(type, name, input) do
    kind = type_string(type)

    if Lux.Native.loaded?() do
      input_json = Jason.encode!(input)
      component = "#{kind}:#{name}"

      case Lux.Native.rust_execute_component(component, input_json) do
        {:ok, result_json} ->
          case Jason.decode(result_json) do
            {:ok, result} -> {:ok, result}
            {:error, _} -> {:ok, result_json}
          end

        {:error, error} ->
          {:error, error}
      end
    else
      {:error, "Rust native library not loaded"}
    end
  end

  @doc """
  Lists all registered components of a given type.

  Returns a list of component metadata maps.
  """
  @spec list(component_type()) :: {:ok, [map()]} | {:error, String.t()}
  def list(type) do
    kind = type_string(type)

    if Lux.Native.loaded?() do
      case Lux.Native.rust_list_components(kind) do
        components when is_list(components) ->
          {:ok, Enum.map(components, &Map.new/1)}

        {:error, error} ->
          {:error, error}
      end
    else
      {:error, "Rust native library not loaded"}
    end
  end

  @doc """
  Unregisters a component by type and name.
  """
  @spec unregister(component_type(), String.t()) :: :ok | {:error, String.t()}
  def unregister(type, name) do
    kind = type_string(type)

    if Lux.Native.loaded?() do
      case Lux.Native.rust_unregister_component(kind, name) do
        true -> :ok
        false -> {:error, "Component not found: #{kind}:#{name}"}
      end
    else
      {:error, "Rust native library not loaded"}
    end
  end

  @doc """
  Returns the count of registered components by type.
  """
  @spec count(component_type()) :: non_neg_integer()
  def count(type) do
    case list(type) do
      {:ok, components} -> length(components)
      _ -> 0
    end
  end

  defp type_string(:prism), do: "prism"
  defp type_string(:beam), do: "beam"
  defp type_string(:lens), do: "lens"
  defp type_string(other) when is_binary(other), do: other

  defp validate_definition("prism", nil, _), do: {:error, "Prism requires :handler code"}
  defp validate_definition("beam", _, nil), do: {:error, "Beam requires :execute code"}
  defp validate_definition(_, _, _), do: :ok
end
