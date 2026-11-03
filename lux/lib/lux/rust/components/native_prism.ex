defmodule Lux.Rust.Components.NativePrism do
  @moduledoc """
  A behaviour and macro that exposes a native Rust component as a first-class Lux Prism.

  ## Example

      defmodule MyApp.Prisms.MatrixMultiply do
        use Lux.Rust.Components.NativePrism,
          rust_component: "RustMatrixMultiply"
      end

      {:ok, result} = MyApp.Prisms.MatrixMultiply.handler(%{
        "a" => [1.0, 2.0],
        "b" => [3.0, 4.0]
      }, %{})
  """

  defmacro __using__(opts) do
    component_name = Keyword.fetch!(opts, :rust_component)

    quote do
      alias Lux.Rust.Components.Registry

      use Lux.Prism,
        name: unquote(component_name),
        description: "Native Rust Prism: #{unquote(component_name)}",
        input_schema: %{type: :object},
        output_schema: %{type: :object}

      @rust_component unquote(component_name)

      @impl true
      def handler(inputs, context) do
        Registry.invoke(@rust_component, inputs, context)
      end
    end
  end
end
