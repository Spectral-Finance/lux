defmodule Lux.Rust.Component do
  @moduledoc """
  Define Lux components (Prisms and Beams) backed by Rust NIFs.

  Provides a macro-based DSL for defining high-performance native components
  with full framework integration, schema validation, and lifecycle management.

  ## Usage

      defmodule MyApp.FastJsonValidator do
        use Lux.Rust.Component,
          type: :prism,
          name: "Fast JSON Validator",
          description: "Validates JSON using Rust NIF"

        @impl true
        def handle(params, _context) do
          schema = params["schema"] || params[:schema]
          data = params["data"] || params[:data]

          case Lux.Rust.validate(data, schema) do
            :ok -> {:ok, %{valid: true}}
            {:error, reason} -> {:ok, %{valid: false, error: reason}}
          end
        end
      end
  """

  defmacro __using__(opts) do
    type = Keyword.get(opts, :type, :prism)
    name = Keyword.get(opts, :name, "Rust Component")
    description = Keyword.get(opts, :description, "A Rust-backed component")

    quote do
      @behaviour Lux.Rust.Component
      @component_type unquote(type)
      @component_name unquote(name)
      @component_description unquote(description)
      @before_compile Lux.Rust.Component

      import Lux.Rust.Component, only: [defnif: 2]

      def __component_type__, do: @component_type
      def __component_name__, do: @component_name
      def __component_description__, do: @component_description

      # Default lifecycle hooks
      def init(_opts), do: :ok
      def terminate(_reason), do: :ok

      defoverridable [init: 1, terminate: 1]
    end
  end

  @callback handle(params :: map(), context :: map()) :: {:ok, term()} | {:error, term()}
  @callback init(opts :: keyword()) :: :ok | {:error, term()}
  @callback terminate(reason :: term()) :: :ok

  @optional_callbacks [init: 1, terminate: 1]

  defmacro __before_compile__(env) do
    unless Module.defines?(env.module, {:handle, 2}) do
      raise CompileError,
        description: "#{env.module} must implement handle/2 callback",
        file: env.file,
        line: env.line
    end
  end

  @doc """
  Define a NIF-backed function within a component.
  Delegates to Lux.Native for the actual NIF call.
  """
  defmacro defnif(name, do: body) do
    quote do
      def unquote(name)(args) do
        unquote(body)
      end
    end
  end
end
