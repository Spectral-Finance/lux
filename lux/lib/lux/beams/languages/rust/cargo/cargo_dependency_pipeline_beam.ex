defmodule Lux.Beams.Languages.Rust.Cargo.CargoDependencyPipelineBeam do
  @moduledoc """
  A beam orchestrating the Cargo package management lifecycle:
  1. Adds or updates a required dependency in `Cargo.toml`.
  2. Audits and resolves all declared dependencies.
  3. Builds the native crate with configured profile options.
  4. Inspects cache state.

  ## Example Usage

  ```elixir
  {:ok, result, execution_log} = Lux.Beams.Languages.Rust.Cargo.CargoDependencyPipelineBeam.run(%{
    crate: "hex",
    version: "0.4.3",
    features: ["alloc"],
    release: true
  })
  ```
  """

  use Lux.Beam,
    name: "Cargo Dependency Management Pipeline",
    description: "Orchestrates adding crates, auditing dependencies, and compiling native Rust projects",
    input_schema: %{
      type: :object,
      properties: %{
        crate: %{
          type: :string,
          description: "Name of the crate to add"
        },
        version: %{
          type: :string,
          description: "Semver constraint",
          default: "1.0"
        },
        features: %{
          type: :array,
          items: %{type: :string},
          default: []
        },
        release: %{
          type: :boolean,
          default: true
        }
      },
      required: ["crate"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        crate: %{type: :string},
        compiled: %{type: :boolean},
        dependencies_count: %{type: :integer}
      },
      required: ["crate", "compiled"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Languages.Rust.Cargo.AddDependencyPrism
  alias Lux.Prisms.Languages.Rust.Cargo.AuditPrism
  alias Lux.Prisms.Languages.Rust.Cargo.BuildPrism
  alias Lux.Prisms.Languages.Rust.Cargo.CachePrism

  sequence do
    # Step 1: Add dependency to Cargo.toml
    step(:add_dependency, AddDependencyPrism, %{
      crate: [:input, :crate],
      version: [:input, :version],
      features: [:input, :features]
    })

    # Step 2: Audit declared dependencies
    step(:audit, AuditPrism, %{})

    # Step 3: Compile crate
    step(:build, BuildPrism, %{
      release: [:input, :release]
    })

    # Step 4: Verify cache
    step(:cache, CachePrism, %{})
  end
end
