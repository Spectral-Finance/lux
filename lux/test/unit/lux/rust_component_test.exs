defmodule Lux.RustComponentTest do
  use UnitAPICase, async: false

  alias Lux.RustComponent

  # ---------------------------------------------------------------------------
  # Test component module defined using the __using__ macro
  # ---------------------------------------------------------------------------
  defmodule TestCounter do
    use Lux.RustComponent,
      name: "Test Counter",
      description: "Counts items via Rust",
      component_type: :prism,
      rust_module: "test_counter"

    @impl true
    def init(_opts), do: {:ok, %{count: 0}}

    @impl true
    def run(items, _context, state) when is_list(items) do
      {:ok, %{count: length(items), state: state}}
    end

    def run(_, _context, _state) do
      {:error, "Expected a list"}
    end
  end

  defmodule TestBeam do
    use Lux.RustComponent,
      name: "Test Beam",
      description: "A test Beam implemented in Rust",
      component_type: :beam,
      rust_module: "test_beam"

    @impl true
    def init(_opts), do: {:ok, %{ready: true}}

    @impl true
    def run(input, _context, state) do
      {:ok, %{input: input, state: state}}
    end
  end

  # ---------------------------------------------------------------------------
  # __using__ macro
  # ---------------------------------------------------------------------------
  describe "use Lux.RustComponent" do
    test "view/0 returns the component struct" do
      comp = TestCounter.view()
      assert %RustComponent{} = comp
      assert comp.name == "Test Counter"
      assert comp.description == "Counts items via Rust"
      assert comp.component_type == :prism
      assert comp.rust_module == "test_counter"
      assert comp.status == :idle
    end

    test "start/1 initialises the component" do
      assert {:ok, %{component: comp, state: state}} = TestCounter.start([])
      assert comp.status == :idle
      assert state == %{count: 0}
    end

    test "execute/2 runs the component's run/3 callback" do
      assert {:ok, %{count: 3}} = TestCounter.execute([1, 2, 3])
    end

    test "execute/2 returns error for invalid input" do
      assert {:error, "Expected a list"} = TestCounter.execute("not a list")
    end

    test "beam component view/0 returns :beam type" do
      comp = TestBeam.view()
      assert comp.component_type == :beam
      assert comp.name == "Test Beam"
    end
  end

  # ---------------------------------------------------------------------------
  # Struct creation
  # ---------------------------------------------------------------------------
  describe "new/1" do
    test "creates a component with defaults" do
      comp = RustComponent.new(name: "My Component", component_type: :prism)
      assert comp.name == "My Component"
      assert comp.status == :idle
      assert is_binary(comp.id)
    end

    test "creates a component with all fields" do
      comp =
        RustComponent.new(
          name: "Rust Beam",
          description: "Fast beam",
          component_type: :beam,
          rust_module: "fast_beam",
          metadata: %{version: "1.0"}
        )

      assert comp.component_type == :beam
      assert comp.rust_module == "fast_beam"
      assert comp.metadata.version == "1.0"
    end
  end

  # ---------------------------------------------------------------------------
  # Lifecycle management
  # ---------------------------------------------------------------------------
  describe "lifecycle" do
    test "start/1 transitions status to :running" do
      comp = RustComponent.new(name: "Test")
      assert comp.status == :idle
      running = RustComponent.start(comp)
      assert running.status == :running
      assert running.pid == self()
    end

    test "stop/1 transitions status to :terminated" do
      comp = RustComponent.new(name: "Test")
      running = RustComponent.start(comp)
      stopped = RustComponent.stop(running)
      assert stopped.status == :terminated
      assert stopped.pid == nil
    end

    test "running?/1 returns true when status is :running" do
      comp = RustComponent.new(name: "Test")
      assert RustComponent.running?(comp) == false
      running = RustComponent.start(comp)
      assert RustComponent.running?(running) == true
    end
  end

  # ---------------------------------------------------------------------------
  # Rust NIF execution
  # ---------------------------------------------------------------------------
  describe "execute/3" do
    test "executes a NIF function and returns a result map" do
      result = RustComponent.execute("test_module", "test_fn", %{input: "hello"})
      assert {:ok, %{module: "test_module", function: "test_fn", result: _}} = result
    end

    test "works with various input types" do
      assert {:ok, _} = RustComponent.execute("m", "f", [1, 2, 3])
      assert {:ok, _} = RustComponent.execute("m", "f", "string input")
      assert {:ok, _} = RustComponent.execute("m", "f", 42)
    end
  end

  describe "execute_with_lifecycle/3" do
    test "runs a component and returns updated struct and result" do
      comp = RustComponent.new(name: "Lifecycle Test", rust_module: "lux_nif")
      result = RustComponent.execute_with_lifecycle(comp, "run", "test input")
      assert {:ok, %RustComponent{status: :terminated}, _result} = result
    end

    test "component status is :terminated after successful run" do
      comp = RustComponent.new(name: "Test", rust_module: "any_module")
      {:ok, final_comp, _result} = RustComponent.execute_with_lifecycle(comp, "run", "input")
      assert final_comp.status == :terminated
    end
  end

  # ---------------------------------------------------------------------------
  # Trait system
  # ---------------------------------------------------------------------------
  describe "traits/0" do
    test "returns the list of supported traits" do
      traits = RustComponent.traits()
      assert :runnable in traits
      assert :async_capable in traits
      assert :lifecycle_managed in traits
    end
  end

  describe "rust_component?/1" do
    test "returns true for modules using Lux.RustComponent" do
      assert RustComponent.rust_component?(TestCounter) == true
      assert RustComponent.rust_component?(TestBeam) == true
    end

    test "returns false for non-component modules" do
      assert RustComponent.rust_component?(Enum) == false
      assert RustComponent.rust_component?(String) == false
    end
  end

  # ---------------------------------------------------------------------------
  # Performance optimisation
  # ---------------------------------------------------------------------------
  describe "optimise/2" do
    test "adds performance metadata to the component" do
      comp = RustComponent.new(name: "Opt Test")
      optimised = RustComponent.optimise(comp, thread_pool_size: 8, buffer_size: 8192)
      assert optimised.metadata.thread_pool_size == 8
      assert optimised.metadata.buffer_size == 8192
      assert optimised.metadata.optimised == true
    end

    test "uses sensible defaults when no options given" do
      comp = RustComponent.new(name: "Default Opt")
      optimised = RustComponent.optimise(comp)
      assert is_integer(optimised.metadata.thread_pool_size)
      assert optimised.metadata.thread_pool_size > 0
    end
  end

  # ---------------------------------------------------------------------------
  # Component registry
  # ---------------------------------------------------------------------------
  describe "register/1 and lookup/1" do
    test "registers and looks up a component by ID" do
      comp = RustComponent.new(name: "Registered Component")
      assert :ok = RustComponent.register(comp)
      assert {:ok, ^comp} = RustComponent.lookup(comp.id)
    end

    test "returns error for unknown IDs" do
      assert {:error, _} = RustComponent.lookup("nonexistent-id-#{System.unique_integer()}")
    end
  end

  describe "list_registered/0" do
    test "returns all registered components" do
      comp1 = RustComponent.new(name: "Comp 1")
      comp2 = RustComponent.new(name: "Comp 2")
      RustComponent.register(comp1)
      RustComponent.register(comp2)
      registered = RustComponent.list_registered()
      assert is_list(registered)
      assert length(registered) >= 2
    end
  end

  # ---------------------------------------------------------------------------
  # Metrics
  # ---------------------------------------------------------------------------
  describe "metrics/1" do
    test "returns metrics map for a component" do
      comp = RustComponent.new(name: "Metrics Test", rust_module: "my_module")
      m = RustComponent.metrics(comp)
      assert m.name == "Metrics Test"
      assert m.rust_module == "my_module"
      assert m.status == :idle
      assert is_list(m.traits)
    end
  end
end
