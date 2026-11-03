defmodule Lux.Prisms.Languages.Rust.Components.InvokePrism do
  @moduledoc """
  A prism for invoking a native Rust component with context and arguments.
  """

  use Lux.Prism,
    name: "Rust Component Invoker",
    description: "Invokes a native Rust Prism or Beam component",
    input_schema: %{
      type: :object,
      properties: %{
        component_name: %{
          type: :string,
          description: "Name of the component to invoke"
        },
        args: %{
          type: [:object, :array, :string, :number]
        },
        context: %{
          type: :object,
          default: %{}
        }
      },
      required: ["component_name", "args"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        result: %{type: [:number, :string, :object, :array, :boolean, :null]},
        component_name: %{type: :string},
        success: %{type: :boolean}
      },
      required: ["result", "component_name", "success"]
    }

  alias Lux.Rust.Components.Registry

  @impl true
  def handler(inputs, _ctx) do
    component_name = Map.get(inputs, "component_name") || Map.get(inputs, :component_name)
    args = Map.get(inputs, "args") || Map.get(inputs, :args, %{})
    custom_ctx = Map.get(inputs, "context") || Map.get(inputs, :context, %{})

    case Registry.invoke(component_name, args, custom_ctx) do
      {:ok, result} ->
        {:ok,
         %{
           result: result,
           component_name: component_name,
           success: true
         }}

      {:error, reason} ->
        {:error, "Invocation failed for #{component_name}: #{inspect(reason)}"}
    end
  end
end
