defmodule Lux.Rust.CargoManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.CargoPrism

  test "run_cargo_command/1 runs a Cargo command" do
    assert capture_io(:stdio, fn ->
      CargoPrism.run_cargo_command("build")
    end) == "Running Cargo command: build\n"
  end

  test "add_cargo_dependency/3 adds a Cargo dependency" do
    {:ok, _} = CargoPrism.add_cargo_dependency("MyModule", "some_dependency", "1.0.0")
    assert true # Assuming the function returns :ok on success
  end
end

test "generate_cargo_toml/1 generates a Cargo.toml file" do
  content = CargoPrism.generate_cargo_toml(%{name: "MyProject", version: "0.1.0"})
  expected_content = """
  [package]
  name = "MyProject"
  version = "0.1.0"

  [dependencies]
  """

  assert content == expected_content
end