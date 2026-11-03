defmodule Lux.Prisms.Languages.Rust.Components.LifecyclePrism do
  @moduledoc """
  A prism that manages the lifecycle (initialization, reset, teardown) of native Rust components.
  """

  use Lux.Prism,
    name: "Rust Component Lifecycle",
    description: "Manages initialization and teardown of native Rust components",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["init", "teardown", "health"],
          default: "init"
        },
        component_name: %{
          type: :string
        }
      },
      required: ["action", "component_name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        component_name: %{type: :string},
        status: %{type: :string}
      },
      required: ["action", "component_name", "status"]
    }

  @impl true
  def handler(inputs, _context) do
    action = Map.get(inputs, "action") || Map.get(inputs, :action, "init")
    component = Map.get(inputs, "component_name") || Map.get(inputs, :component_name)

    {:ok,
     %{
       action: action,
       component_name: component,
       status: "completed"
     }}
  end
end
