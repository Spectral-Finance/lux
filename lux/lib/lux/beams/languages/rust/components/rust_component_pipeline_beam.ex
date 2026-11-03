defmodule Lux.Beams.Languages.Rust.Components.RustComponentPipelineBeam do
  @moduledoc """
  A Beam pipeline for coordinating native Rust component execution.

  The pipeline manages:
  1. Synchronizing and validating component schemas (`SchemaSyncPrism`)
  2. Initializing component lifecycle state (`LifecyclePrism`)
  3. Invoking the component with arguments and execution context (`InvokePrism`)
  4. Performing component teardown or cleanup (`LifecyclePrism`)

  ## Example Usage

  ```elixir
  {:ok, result} = Lux.Beams.Languages.Rust.Components.RustComponentPipelineBeam.run(%{
    component_name: "matrix_multiply",
    args: %{
      a: [[1, 2], [3, 4]],
      b: [[5, 6], [7, 8]]
    },
    context: %{precision: "f64"}
  })
  ```
  """

  use Lux.Beam,
    name: "Rust Component Pipeline Beam",
    description: "Orchestrates schema synchronization, lifecycle management, and execution of native Rust components",
    input_schema: %{
      type: :object,
      properties: %{
        component_name: %{
          type: :string,
          description: "Name of the registered native Rust component"
        },
        args: %{
          type: [:object, :array, :string, :number],
          description: "Input payload to supply to the component"
        },
        context: %{
          type: :object,
          description: "Execution context metadata passed to the component",
          default: %{}
        }
      },
      required: ["component_name", "args"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        component_name: %{type: :string},
        success: %{type: :boolean},
        result: %{type: [:number, :string, :object, :array, :boolean, :null]},
        status: %{type: :string}
      },
      required: ["component_name", "success", "status"]
    }

  alias Lux.Prisms.Languages.Rust.Components.InvokePrism
  alias Lux.Prisms.Languages.Rust.Components.LifecyclePrism
  alias Lux.Prisms.Languages.Rust.Components.SchemaSyncPrism

  sequence do
    step(:sync_schema, SchemaSyncPrism, %{
      component_name: [:input, :component_name]
    })

    step(:init_lifecycle, LifecyclePrism, %{
      component_name: [:input, :component_name],
      action: "init"
    })

    step(:invoke_component, InvokePrism, %{
      component_name: [:input, :component_name],
      args: [:input, :args],
      context: [:input, :context]
    })

    step(:teardown_lifecycle, LifecyclePrism, %{
      component_name: [:input, :component_name],
      action: "teardown"
    })
  end
end
