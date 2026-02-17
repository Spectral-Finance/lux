defmodule Lux.Rust.CargoPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.CargoPrism

  test "run_cargo_command/1 runs a Cargo command" do
    CargoPrism.run_cargo_command("build")
    assert_received {:puts, "Running Cargo command: build"}
  end

  test "add_cargo_dependency/3 adds a Cargo dependency" do
    result = CargoPrism.add_cargo_dependency("MyModule", "some_dependency", "1.0.0")
    assert result == :ok
  end

  test "structure_of_cargo_prism/0 returns the structure of CargoPrism" do
    expected_structure = %{
      module: "Lux.Rust.CargoPrism",
      functions: [
        %{name: "run_cargo_command", description: "Runs a Cargo command"},
        %{name: "add_cargo_dependency", description: "Adds a Cargo dependency"}
      ]
    }
    assert CargoPrism.structure_of_cargo_prism() == expected_structure
  end
end

test "resolve_cargo_dependency/1 resolves a Cargo dependency" do
  result = CargoPrism.resolve_cargo_dependency("some_dependency")
  assert result == {:ok, "Dependency resolved: some_dependency"}
end