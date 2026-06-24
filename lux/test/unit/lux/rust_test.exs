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

    test "builds a beam definition" do
      assert {:ok, definition} =
               Lux.Rust.beam_definition(%{
                 name: "TradingBeam",
                 module: "trading_beam",
                 handler: "run",
                 async: true
               })

      assert definition.kind == :beam
      assert definition.traits == [:lux_component, :lux_beam]
    end

    test "builds a lens definition" do
      assert {:ok, definition} =
               Lux.Rust.lens_definition(%{
                 name: "PriceLens",
                 module: "price_lens",
                 handler: "fetch"
               })

      assert definition.kind == :lens
      assert definition.traits == [:lux_component, :lux_lens]
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
      assert runtime.performance.telemetry.duration == true
    end

    test "builds lifecycle plan with all stages" do
      lifecycle = Lux.Rust.lifecycle_plan(%{
        module: "my_prism",
        handler: "process",
        timeout_ms: 10_000
      })

      assert lifecycle.states == [:defined, :compiled, :loaded, :started, :called, :stopped]
      assert lifecycle.load.module == "my_prism"
      assert lifecycle.load.symbol == "process"
      assert lifecycle.call.timeout_ms == 10_000
      assert lifecycle.call.error_boundary == :result_tuple
    end

    test "generates component template" do
      template = Lux.Rust.component_template(%{
        name: "ExamplePrism",
        struct: "ExamplePrism",
        kind: :prism
      })

      assert template =~ "pub struct ExamplePrism"
      assert template =~ "impl LuxComponent for ExamplePrism"
      assert template =~ "fn name"
      assert template =~ "fn handle"
    end

    test "validates a correct component definition" do
      {:ok, definition} = Lux.Rust.prism_definition(%{
        name: "TestPrism",
        module: "test_prism",
        handler: "handle"
      })

      validation = Lux.Rust.validate_component(definition)
      assert validation.valid == true
      assert validation.errors == []
    end

    test "rejects invalid component definitions" do
      assert %{valid: false, errors: errors} =
               Lux.Rust.validate_component(%{not_rust: true})

      assert errors == [:not_a_rust_component]
    end
  end
end
