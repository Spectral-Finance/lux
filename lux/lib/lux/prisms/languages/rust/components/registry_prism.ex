defmodule Lux.Prisms.Languages.Rust.Components.RegistryPrism do
  @moduledoc """
  A prism that inspects and queries all registered native Rust components.
  """

  use Lux.Prism,
    name: "Rust Component Registry Inspector",
    description: "Lists and inspects registered native Rust components (Prisms and Beams)",
    input_schema: %{
      type: :object,
      properties: %{
        filter: %{
          type: :string,
          description: "Optional component name filter"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        components_count: %{type: :integer},
        components: %{type: :array},
        status: %{type: :string}
      },
      required: ["components_count", "components", "status"]
    }

  alias Lux.Rust.Components.Registry

  @impl true
  def handler(inputs, _context) do
    filter = Map.get(inputs, "filter") || Map.get(inputs, :filter)
    all_components = Registry.list_components()

    filtered =
      if filter do
        Enum.filter(all_components, fn c ->
          String.contains?(String.downcase(c.name), String.downcase(filter))
        end)
      else
        all_components
      end

    {:ok,
     %{
       components_count: length(filtered),
       components: filtered,
       status: "ok"
     }}
  end
end
