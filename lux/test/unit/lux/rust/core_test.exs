defmodule Lux.Rust.CoreTest do
  use UnitCase, async: false

  alias Lux.Rust.Core

  @manifest_path Path.expand("../../../../priv/rust/lux_core/Cargo.toml", __DIR__)

  test "reports native project availability" do
    assert Core.native_available?(manifest_path: @manifest_path)
  end

  test "builds command plans without executing Rust" do
    plan = Core.command_plan(:echo, %{"hello" => "rust"}, manifest_path: @manifest_path)

    assert ["cargo", "run", "--quiet", "--manifest-path", @manifest_path, "--", "echo", payload] =
             plan.command

    assert {:ok, decoded} = payload |> Base.decode64!() |> Jason.decode()
    assert decoded == %{"hello" => "rust"}
  end

  test "round-trips JSON values through Rust" do
    input = %{"name" => "lux", "count" => 2, "active" => true}

    assert {:ok, ^input} = Core.execute(:echo, input, manifest_path: @manifest_path)
  end

  test "maps primitive JSON types in Rust" do
    assert {:ok, "string"} = Core.type_of("lux", manifest_path: @manifest_path)
    assert {:ok, "integer"} = Core.type_of(42, manifest_path: @manifest_path)
    assert {:ok, "array"} = Core.type_of([1, 2, 3], manifest_path: @manifest_path)
  end

  test "executes native integer operations" do
    assert {:ok, 15} = Core.sum_i64([4, 5, 6], manifest_path: @manifest_path)
  end

  test "propagates typed Rust errors" do
    assert {:error, %{code: "type_error", message: message}} =
             Core.sum_i64([1, "2"], manifest_path: @manifest_path)

    assert message =~ "expected integer"

    assert {:error, %{code: "unknown_operation"}} =
             Core.execute(:missing_operation, %{}, manifest_path: @manifest_path)
  end
end
