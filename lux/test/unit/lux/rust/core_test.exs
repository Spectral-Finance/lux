defmodule Lux.Rust.CoreTest do
  use ExUnit.Case, async: true
  alias Lux.Rust.Core

  test "generates priv/rust crate layout and marshals Elixir primitives safely" do
    {:ok, layout} = Core.project_layout("lux_native")
    assert layout.root_dir == "priv/rust/lux_native"
    assert {:error, :invalid_crate_name} = Core.project_layout("Invalid-Crate")

    assert {:ok, %{rust_type: :u64, value: 42}} = Core.marshal_primitive(:u64, 42)
    assert {:error, {:type_mismatch, :u64, -1}} = Core.marshal_primitive(:u64, -1)
  end
end
