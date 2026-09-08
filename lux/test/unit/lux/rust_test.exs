defmodule Lux.RustTest do
  use ExUnit.Case, async: true

  describe "module_path/0" do
    test "points at priv/rust" do
      path = Lux.Rust.module_path()
      assert is_binary(path)
      assert String.ends_with?(path, "priv/rust") or String.contains?(path, "priv/rust")
    end
  end

  describe "when the NIF is not required" do
    test "available?/0 returns a boolean" do
      assert is_boolean(Lux.Rust.available?())
    end
  end

  describe "NIF integration" do
    setup do
      if Lux.Rust.available?() do
        :ok
      else
        {:skip, "Rust NIF not loaded (compile lux_core via mix compile)"}
      end
    end

    test "version/0 returns the crate version" do
      assert {:ok, version} = Lux.Rust.version()
      assert version =~ ~r/^\d+\.\d+\.\d+$/
    end

    test "add/2 converts integers and returns the sum" do
      assert {:ok, 42} = Lux.Rust.add(40, 2)
      assert {:ok, -1} = Lux.Rust.add(-3, 2)
    end

    test "add/2 rejects non-integers without calling the NIF" do
      assert {:error, {:type, "integer", "other"}} = Lux.Rust.add("40", 2)
    end

    test "divide/2 propagates a runtime error on division by zero" do
      assert {:error, {:runtime, "division by zero"}} = Lux.Rust.divide(1, 0)
      assert {:ok, 21} = Lux.Rust.divide(42, 2)
    end

    test "echo/1 round-trips primitive types" do
      assert {:ok, nil} = Lux.Rust.echo(nil)
      assert {:ok, true} = Lux.Rust.echo(true)
      assert {:ok, false} = Lux.Rust.echo(false)
      assert {:ok, 7} = Lux.Rust.echo(7)
      assert {:ok, 1.5} = Lux.Rust.echo(1.5)
      assert {:ok, :hello} = Lux.Rust.echo(:hello)
      assert {:ok, "lux"} = Lux.Rust.echo("lux")
      assert {:ok, [1, 2, 3]} = Lux.Rust.echo([1, 2, 3])
      assert {:ok, {1, "a"}} = Lux.Rust.echo({1, "a"})
      assert {:ok, %{"k" => 1}} = Lux.Rust.echo(%{"k" => 1})
    end

    test "describe/1 reports converted types" do
      assert {:ok, %{"type" => "integer", "value" => 9}} = Lux.Rust.describe(9)
      assert {:ok, %{"type" => "nil", "value" => nil}} = Lux.Rust.describe(nil)
      assert {:ok, %{"type" => "list", "value" => 3}} = Lux.Rust.describe([:a, :b, :c])
      assert {:ok, %{"type" => "boolean", "value" => true}} = Lux.Rust.describe(true)
    end

    test "type_error/0 returns a structured type reason" do
      assert {:error, {:type, "integer", "atom"}} = Lux.Rust.type_error()
    end

    test "fib/1 runs on the dirty CPU scheduler" do
      assert {:ok, 0} = Lux.Rust.fib(0)
      assert {:ok, 1} = Lux.Rust.fib(1)
      assert {:ok, 55} = Lux.Rust.fib(10)
      assert {:error, {:runtime, message}} = Lux.Rust.fib(100)
      assert message =~ "overflow"
    end

    test "wrap_ok/1 builds an ok tuple in Rust" do
      assert {:ok, 42} = Lux.Rust.wrap_ok(42)
    end
  end
end
