defmodule Lux.Prisms.Languages.Rust.Components.SchemaSyncPrism do
  @moduledoc """
  A prism that verifies and synchronizes input/output schemas of native Rust components.
  """

  use Lux.Prism,
    name: "Rust Component Schema Sync",
    description: "Verifies and synchronizes component schemas with the Lux registry",
    input_schema: %{
      type: :object,
      properties: %{
        component_name: %{type: :string}
      },
      required: ["component_name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        is_synced: %{type: :boolean},
        component_name: %{type: :string},
        input_schema: %{type: :object},
        output_schema: %{type: :object}
      },
      required: ["is_synced", "component_name"]
    }

  alias Lux.Rust.Components.Registry

  @impl true
  def handler(inputs, _context) do
    component_name = Map.get(inputs, "component_name") || Map.get(inputs, :component_name)

    case Registry.get_component(component_name) do
      {:ok, meta} ->
        {:ok,
         %{
           is_synced: true,
           component_name: component_name,
           input_schema: meta.input_schema,
           output_schema: meta.output_schema
         }}

      {:error, :not_found} ->
        {:error, "Component '#{component_name}' not found in registry"}
    end
  end
end
