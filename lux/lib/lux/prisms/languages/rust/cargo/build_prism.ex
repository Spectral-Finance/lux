defmodule Lux.Prisms.Languages.Rust.Cargo.BuildPrism do
  @moduledoc """
  A prism for compiling the native Rust codebase using Cargo.
  """

  use Lux.Prism,
    name: "Cargo Build",
    description: "Compiles the native Rust project using Cargo",
    input_schema: %{
      type: :object,
      properties: %{
        release: %{
          type: :boolean,
          description: "Whether to build with --release",
          default: true
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        compiled: %{type: :boolean},
        mode: %{type: :string},
        status: %{type: :string}
      },
      required: ["compiled", "mode", "status"]
    }

  alias Lux.Rust.Cargo

  @impl true
  def handler(inputs, _context) do
    release = Map.get(inputs, "release") || Map.get(inputs, :release, true)

    case Cargo.build(release: release) do
      {:ok, result} ->
        {:ok,
         %{
           compiled: result.compiled,
           mode: result.mode,
           status: "success"
         }}

      {:error, reason} ->
        {:error, "Cargo build failed: #{inspect(reason)}"}
    end
  end
end
