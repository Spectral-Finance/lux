defmodule Lux.Rust.ComponentTest do
  use UnitCase, async: false

  alias Lux.Rust.Component

  @moduletag :unit

  # ── Test helper modules ───────────────────────────────────────────────────────

  # A minimal module that satisfies Lux.Rust.Component.Behaviour
  defmodule MockBehaviourNif do
    @behaviour Lux.Rust.Component.Behaviour

    @impl true
    def nif_path, do: "/fake/path/mock_nif"

    @impl true
    def nif_functions, do: [:echo, :double]

    @impl true
    def handle_call(:echo, [value]), do: {:ok, value}
    def handle_call(:double, [n]) when is_integer(n), do: {:ok, n * 2}
    def handle_call(name, args), do: {:error, "unknown: #{name}/#{length(args)}"}
  end

  # A plain module that exposes a function but is not a behaviour implementation
  defmodule PlainNif do
    def compute(x), do: {:ok, x + 1}
  end

  # A module with lifecycle callbacks
  defmodule LifecycleNif do
    @behaviour Lux.Rust.Component.Behaviour

    @impl true
    def nif_path, do: "/fake/path/lifecycle_nif"

    @impl true
    def nif_functions, do: [:run]

    @impl true
    def handle_call(:run, _args), do: {:ok, :ran}

    def lifecycle_init, do: :ok
    def lifecycle_cleanup, do: :ok
  end

  # ── Registry ─────────────────────────────────────────────────────────────────

  describe "register_component/2" do
    test "registers a component and returns :ok" do
      assert :ok = Component.register_component(MockBehaviourNif, %{version: "1.0.0"})
    end

    test "overwrites an existing registration" do
      :ok = Component.register_component(MockBehaviourNif, %{version: "1.0.0"})
      :ok = Component.register_component(MockBehaviourNif, %{version: "2.0.0"})

      {:ok, info} = Component.component_info(MockBehaviourNif)
      assert info.version == "2.0.0"
    end

    test "accepts empty metadata map" do
      assert :ok = Component.register_component(PlainNif, %{})
    end

    test "always sets :module and :registered_at keys" do
      :ok = Component.register_component(MockBehaviourNif, %{custom: "data"})
      {:ok, info} = Component.component_info(MockBehaviourNif)

      assert info.module == MockBehaviourNif
      assert %DateTime{} = info.registered_at
    end
  end

  describe "list_components/0" do
    setup do
      # Ensure a fresh table for each test
      if :ets.whereis(:lux_rust_components) != :undefined do
        :ets.delete_all_objects(:lux_rust_components)
      end

      :ok
    end

    test "returns an empty list when no components are registered" do
      assert Component.list_components() == []
    end

    test "returns all registered components" do
      Component.register_component(MockBehaviourNif, %{role: :prism})
      Component.register_component(PlainNif, %{role: :util})

      components = Component.list_components()
      modules = Enum.map(components, & &1.module)

      assert MockBehaviourNif in modules
      assert PlainNif in modules
    end

    test "each entry includes the module key" do
      Component.register_component(MockBehaviourNif, %{})
      [entry | _] = Component.list_components()

      assert Map.has_key?(entry, :module)
    end
  end

  describe "component_info/1" do
    test "returns {:ok, info} for a registered component" do
      :ok = Component.register_component(MockBehaviourNif, %{tag: "test"})

      assert {:ok, info} = Component.component_info(MockBehaviourNif)
      assert info.tag == "test"
    end

    test "returns {:error, :not_found} for an unregistered module" do
      assert {:error, :not_found} = Component.component_info(DoesNotExistModule)
    end
  end

  # ── NIF loaded? ───────────────────────────────────────────────────────────────

  describe "nif_loaded?/1" do
    test "returns false for a module that has no loaded NIF" do
      refute Component.nif_loaded?(MockBehaviourNif)
    end

    test "returns false for a non-existent module atom" do
      refute Component.nif_loaded?(Totally.NonExistent.Module)
    end
  end

  # ── load_nif/2 ────────────────────────────────────────────────────────────────

  describe "load_nif/2" do
    test "returns {:error, reason} for a non-existent shared library" do
      assert {:error, reason} = Component.load_nif(MockBehaviourNif, "/nonexistent/path/nif")
      assert is_binary(reason) or is_atom(reason)
    end

    test "returns a binary error message describing the failure" do
      assert {:error, msg} = Component.load_nif(MockBehaviourNif, "/nonexistent/path/nif")

      case msg do
        bin when is_binary(bin) -> assert String.length(bin) > 0
        atom when is_atom(atom) -> assert atom != nil
        _ -> flunk("Expected binary or atom error, got: #{inspect(msg)}")
      end
    end
  end

  # ── call_nif/3 ────────────────────────────────────────────────────────────────

  describe "call_nif/3 with Behaviour implementation" do
    test "dispatches to handle_call when module implements the behaviour" do
      assert {:ok, "hello"} = Component.call_nif(MockBehaviourNif, :echo, ["hello"])
    end

    test "doubles an integer via the behaviour dispatch" do
      assert {:ok, 84} = Component.call_nif(MockBehaviourNif, :double, [42])
    end

    test "returns {:error, reason} for unknown function via behaviour" do
      assert {:error, reason} = Component.call_nif(MockBehaviourNif, :unknown_fn, [])
      assert is_binary(reason)
    end
  end

  describe "call_nif/3 with plain module" do
    test "calls exported function directly when module is not a behaviour" do
      assert {:ok, 6} = Component.call_nif(PlainNif, :compute, [5])
    end

    test "returns {:error, reason} for unexported function" do
      assert {:error, reason} = Component.call_nif(PlainNif, :nonexistent, [])
      assert is_binary(reason)
    end
  end

  # ── with_timeout/2 ────────────────────────────────────────────────────────────

  describe "with_timeout/2" do
    test "returns {:ok, result} when the function completes within the timeout" do
      assert {:ok, 42} =
               Component.with_timeout(1_000, fn -> {:ok, 42} end)
    end

    test "returns {:error, :timeout} when the function exceeds the timeout" do
      assert {:error, :timeout} =
               Component.with_timeout(50, fn ->
                 Process.sleep(500)
                 {:ok, :too_late}
               end)
    end

    test "propagates {:error, reason} from the inner function" do
      assert {:error, "boom"} =
               Component.with_timeout(1_000, fn -> {:error, "boom"} end)
    end
  end

  # ── Async support ─────────────────────────────────────────────────────────────

  describe "async_call/3" do
    test "returns {:ok, task} immediately" do
      assert {:ok, %Task{}} =
               Component.async_call(MockBehaviourNif, :echo, ["async_value"])
    end

    test "task resolves to {:ok, result} when awaited" do
      {:ok, task} = Component.async_call(MockBehaviourNif, :echo, ["resolved"])
      assert {:ok, "resolved"} = Component.await_result(task, 1_000)
    end

    test "task resolves to {:error, reason} for unknown function" do
      {:ok, task} = Component.async_call(MockBehaviourNif, :no_such_fn, [])
      assert {:error, _reason} = Component.await_result(task, 1_000)
    end
  end

  describe "await_result/2" do
    test "returns {:error, :timeout} when task does not finish in time" do
      {:ok, task} =
        Component.async_call(MockBehaviourNif, :echo, [
          # simulate slow task by sleeping inside handle_call — we use a
          # plain Task here to avoid mutating the mock module
          :timer.sleep(500)
        ])

      # Only 10 ms allowed — should time out
      assert {:error, _} = Component.await_result(task, 10)
    end
  end

  # ── Lifecycle management ──────────────────────────────────────────────────────

  describe "lifecycle_start/1" do
    test "returns {:ok, :started} for module with lifecycle_init/0" do
      assert {:ok, :started} = Component.lifecycle_start(LifecycleNif)
    end

    test "returns {:ok, :started} for module without lifecycle_init/0" do
      assert {:ok, :started} = Component.lifecycle_start(MockBehaviourNif)
    end

    test "registers the component in the ETS table after starting" do
      :ok =
        if :ets.whereis(:lux_rust_components) != :undefined do
          :ets.delete(:lux_rust_components, LifecycleNif)
          :ok
        else
          :ok
        end

      {:ok, :started} = Component.lifecycle_start(LifecycleNif)
      assert {:ok, info} = Component.component_info(LifecycleNif)
      assert info.status == :started
    end
  end

  describe "lifecycle_stop/1" do
    test "returns {:ok, :stopped} for module with lifecycle_cleanup/0" do
      Component.lifecycle_start(LifecycleNif)
      assert {:ok, :stopped} = Component.lifecycle_stop(LifecycleNif)
    end

    test "returns {:ok, :stopped} for module without lifecycle_cleanup/0" do
      Component.register_component(MockBehaviourNif, %{})
      assert {:ok, :stopped} = Component.lifecycle_stop(MockBehaviourNif)
    end

    test "removes the component from the registry after stopping" do
      Component.lifecycle_start(LifecycleNif)
      {:ok, :stopped} = Component.lifecycle_stop(LifecycleNif)

      assert {:error, :not_found} = Component.component_info(LifecycleNif)
    end
  end

  # ── use Lux.Rust.Component (macro integration) ────────────────────────────────

  describe "rust_prism/2 macro" do
    defmodule SampleRustPrism do
      use Lux.Rust.Component

      rust_prism __MODULE__,
        name: "Sample Rust Prism",
        description: "A prism used for testing the macro",
        input_schema: %{
          type: :object,
          properties: %{value: %{type: :string}}
        }
    end

    test "generated view/0 returns a Lux.Prism struct" do
      prism = SampleRustPrism.view()
      assert %Lux.Prism{} = prism
      assert prism.name == "Sample Rust Prism"
      assert prism.description == "A prism used for testing the macro"
    end

    test "generated view/0 includes input_schema" do
      prism = SampleRustPrism.view()
      assert prism.input_schema.type == :object
    end

    test "generated view/0 sets handler to the module's handler function" do
      prism = SampleRustPrism.view()
      assert is_function(prism.handler, 2)
    end

    test "module satisfies Lux.Prism behaviour (exports handler/2 and run/2)" do
      assert function_exported?(SampleRustPrism, :handler, 2)
      assert function_exported?(SampleRustPrism, :run, 2)
    end
  end

  describe "rust_beam/2 macro" do
    defmodule SampleRustBeam do
      use Lux.Rust.Component

      rust_beam __MODULE__,
        name: "Sample Rust Beam",
        description: "A beam used for testing the macro",
        timeout: :timer.seconds(30)
    end

    test "generated view/0 returns a Lux.Beam struct" do
      beam = SampleRustBeam.view()
      assert %Lux.Beam{} = beam
      assert beam.name == "Sample Rust Beam"
    end

    test "generated view/0 includes the configured timeout" do
      beam = SampleRustBeam.view()
      assert beam.timeout == :timer.seconds(30)
    end

    test "module exports run/2" do
      assert function_exported?(SampleRustBeam, :run, 2)
    end
  end

  # ── Lux.Rust.Component.Behaviour callbacks ────────────────────────────────────

  describe "Lux.Rust.Component.Behaviour" do
    test "MockBehaviourNif correctly implements nif_path/0" do
      assert is_binary(MockBehaviourNif.nif_path())
    end

    test "MockBehaviourNif correctly implements nif_functions/0" do
      fns = MockBehaviourNif.nif_functions()
      assert is_list(fns)
      assert Enum.all?(fns, &is_atom/1)
    end

    test "MockBehaviourNif handle_call returns {:ok, _} for known functions" do
      assert {:ok, _} = MockBehaviourNif.handle_call(:echo, ["test"])
    end

    test "MockBehaviourNif handle_call returns {:error, _} for unknown function" do
      assert {:error, _} = MockBehaviourNif.handle_call(:unknown, [])
    end
  end
end
