defmodule Lux.RustTest do
  use UnitCase, async: true

  import Lux.Rust

  require Lux.Rust

  describe "component definitions" do
    test "builds a prism definition with lifecycle and traits" do
      assert {:ok, definition} =
               Lux.Rust.prism_definition(%{
                 name: "ValidationPrism",
                 module: "validation_prism",
                 handler: "handle",
                 async: true,
                 input_schema: %{type: :object},
                 output_schema: %{type: :object}
               })

      assert definition.language == :rust
      assert definition.kind == :prism
      assert definition.traits == [:lux_component, :lux_prism]
      assert definition.runtime.runtime == :tokio
      assert definition.lifecycle.call.input_encoding == :json
      assert Lux.Rust.validate_component(definition).valid
    end

    test "rejects unknown component kinds" do
      assert {:error, :unknown_component_kind} =
               Lux.Rust.component_definition(%{
                 kind: :unknown,
                 name: "Bad",
                 module: "bad",
                 handler: "handle"
               })
    end
  end

  describe "rust sigil" do
    test "preserves inline Rust code as a component definition" do
      code =
        ~RS"""
        pub fn handle(input: serde_json::Value) -> serde_json::Value {
            input
        }
        """

      assert {:ok, definition} =
               Lux.Rust.component_from_code(code,
                 name: "InlineValidation",
                 module: "inline_validation",
                 kind: :prism
               )

      assert definition.name == "InlineValidation"
      assert definition.code =~ "pub fn handle"
    end
  end

  describe "cargo manifest and dependencies" do
    test "generates Cargo.toml with serde and tokio defaults" do
      manifest = Lux.Rust.cargo_manifest(%{package: "lux-example"})

      assert manifest =~ ~s(name = "lux-example")
      assert manifest =~ ~s(serde = { version = "1", features = ["derive"] })
      assert manifest =~ ~s(tokio = { version = "1", features = ["rt", "macros"] })
    end

    test "builds dependency cache and build commands" do
      plan = Lux.Rust.dependency_plan(%{dependencies: %{"serde_json" => "1"}})

      assert plan.manifest_path =~ "priv/rust/Cargo.toml"
      assert plan.cache_key =~ ~r/^[0-9a-f]{64}$/
      assert Enum.any?(plan.commands, &String.contains?(&1, "cargo build --release"))
    end
  end

  describe "runtime, lifecycle, and templates" do
    test "builds async runtime and performance plans" do
      runtime =
        Lux.Rust.runtime_plan(%{
          async: true,
          max_concurrency: 8,
          queue_limit: 32,
          zero_copy_candidates: [:binary]
        })

      assert runtime.async
      assert runtime.max_concurrency == 8
      assert runtime.backpressure.queue_limit == 32
      assert runtime.performance.zero_copy_candidates == [:binary]
    end

    test "renders a Rust trait implementation template" do
      template =
        Lux.Rust.component_template(%{
          kind: :beam,
          struct: "PipelineBeam",
          name: "Pipeline Beam"
        })

      assert template =~ "impl LuxComponent for PipelineBeam"
      assert template =~ "ComponentKind::Beam"
      assert template =~ ~s("Pipeline Beam")
    end
  end
end
