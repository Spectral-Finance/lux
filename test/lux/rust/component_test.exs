defmodule Lux.Rust.ComponentTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.Component

  describe "new/2" do
    test "creates a component with default attributes" do
      comp = Component.new("test_component")
      assert comp.name == "test_component"
      assert comp.version == "0.1.0"
      assert comp.status == :idle
      assert comp.handlers == %{}
      assert comp.config == %{}
      assert comp.metadata == %{}
      assert comp.registry == %{}
    end

    test "creates a component with custom options" do
      comp = Component.new("my_component",
        version: "1.0.0",
        description: "Test component",
        config: %{key: "value"},
        dependencies: ["dep1", "dep2"]
      )

      assert comp.name == "my_component"
      assert comp.version == "1.0.0"
      assert comp.description == "Test component"
      assert comp.config == %{key: "value"}
      assert comp.dependencies == ["dep1", "dep2"]
    end
  end

  describe "lifecycle - init/2" do
    test "initializes component with default init" do
      comp = Component.new("test")
      assert {:ok, initialized} = Component.init(comp)
      assert initialized.status == :active
      assert initialized.state == %{}
    end

    test "initializes component with custom init function" do
      comp = Component.new("test")
      init_fn = fn %Component{} = c -> {:ok, %{started_at: :os.system_time(:millisecond)}} end
      assert {:ok, initialized} = Component.init(comp, init_fn)
      assert initialized.status == :active
      assert initialized.state[:started_at]
    end

    test "returns error on failed init" do
      comp = Component.new("test")
      fail_fn = fn _ -> {:error, "config missing"} end
      assert {:error, failed} = Component.init(comp, fail_fn)
      assert failed.status == :error
    end
  end

  describe "lifecycle - validate/2" do
    test "validates component config" do
      comp = Component.new("test", config: %{valid: true})
      assert {:ok, %{valid: true}} = Component.validate(comp)
    end

    test "validates with custom function" do
      comp = Component.new("test", config: %{port: 8080})
      validator = fn %Component{} = c ->
        if c.config[:port] > 0, do: {:ok, c.config}, else: {:error, "invalid port"}
      end
      assert {:ok, %{port: 8080}} = Component.validate(comp, validator)
    end
  end

  describe "lifecycle - handle_call/3" do
    test "handles call with default handler" do
      comp = Component.new("test")
      {:reply, result, updated} = Component.handle_call(comp, :ping)
      assert result == :ok
      assert updated == comp
    end

    test "handles call with custom handler" do
      comp = Component.new("test")
      handler = fn %Component{} = c, msg ->
        {:reply, {:ok, msg}, %{c | metadata: %{last_msg: msg}}}
      end

      {:reply, result, updated} = Component.handle_call(comp, :hello, handler)
      assert result == {:ok, :hello}
      assert updated.metadata.last_msg == :hello
    end
  end

  describe "lifecycle - terminate/2" do
    test "terminates component" do
      comp = Component.new("test")
      assert {:ok, terminated} = Component.terminate(comp)
      assert terminated.status == :terminated
      assert terminated.state == nil
    end

    test "terminates with cleanup function" do
      comp = Component.new("test", metadata: %{cleanup_called: false})
      cleanup = fn %Component{} = c ->
        send(self(), :cleaned_up)
        :ok
      end

      assert {:ok, terminated} = Component.terminate(comp, cleanup)
      assert terminated.status == :terminated
    end
  end

  describe "handler registration" do
    test "registers lifecycle handlers" do
      comp = Component.new("test")
      handler = fn _ -> {:ok, :handled} end
      comp = Component.register_handler(comp, :handle_call, handler)
      assert is_function(comp.handlers[:handle_call])
    end

    test "registers prisms" do
      comp = Component.new("test")
      prism_fn = fn _params -> {:ok, [%{id: 1}]} end
      comp = Component.register_prism(comp, :users, prism_fn)
      assert {:ok, [%{id: 1}]} = Component.query_prism(comp, :users)
    end

    test "registers beams" do
      comp = Component.new("test")
      beam_fn = fn _payload -> {:ok, :emitted} end
      comp = Component.register_beam(comp, :alert, beam_fn)
      assert {:ok, :emitted} = Component.emit_beam(comp, :alert)
    end
  end

  describe "prism/beam integration" do
    test "queries an unregistered prism returns error" do
      comp = Component.new("test")
      assert {:error, msg} = Component.query_prism(comp, :nonexistent)
      assert msg =~ "not registered"
    end

    test "emits an unregistered beam returns error" do
      comp = Component.new("test")
      assert {:error, msg} = Component.emit_beam(comp, :nonexistent)
      assert msg =~ "not registered"
    end
  end

  describe "linking and supervision" do
    test "links two components together" do
      comp1 = Component.new("comp1")
      comp2 = Component.new("comp2")
      result = Component.link(comp1, comp2)

      assert comp2.name in result.dependencies
      assert result.metadata[:linked_to] == ["comp1", "comp2"]
    end

    test "creates a supervision tree" do
      comp1 = Component.new("comp1")
      comp2 = Component.new("comp2")
      supervisor = Component.supervise([comp1, comp2], :one_for_one)

      assert supervisor.strategy == :one_for_one
      assert length(supervisor.components) == 2
      assert supervisor.status == :idle
    end
  end
end
