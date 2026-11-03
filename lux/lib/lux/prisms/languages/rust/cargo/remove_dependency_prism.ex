defmodule Lux.Prisms.Languages.Rust.Cargo.RemoveDependencyPrism do
  @moduledoc """
  A prism for removing a dependency from the project's `Cargo.toml`.
  """

  use Lux.Prism,
    name: "Cargo Remove Dependency",
    description: "Removes a crate dependency from Cargo.toml",
    input_schema: %{
      type: :object,
      properties: %{
        crate: %{
          type: :string,
          description: "Name of the crate to remove"
        }
      },
      required: ["crate"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        crate: %{type: :string},
        status: %{type: :string}
      },
      required: ["crate", "status"]
    }

  alias Lux.Rust.Cargo

  @impl true
  def handler(inputs, _context) do
    crate = Map.get(inputs, "crate") || Map.get(inputs, :crate)

    case Cargo.remove_dependency(crate) do
      :ok ->
        {:ok, %{crate: crate, status: "removed"}}

      {:error, reason} ->
        {:error, "Failed to remove crate '#{crate}': #{inspect(reason)}"}
    end
  end
end
