defmodule Lux.RustTest do
  use UnitCase, async: true

  alias Lux.Rust
  alias Lux.Rust.Error

  describe "eval/1" do
    test "returns ok with evaluation result" do
      result = Rust.eval(%{code: "add", a: 10, b: 32})
      assert {:ok, %{"status" => "evaluated", "length" => 3}} = result
    end

    test "includes input variables in result" do
      result = Rust.eval(%{code: "multiply", x: 6, y: 7})
      assert {:ok, result} = result
      assert result["input_vars"] == %{x: 6, y: 7}
    end
  end

  describe "eval!/1" do
    test "returns result directly without ok wrapper" do
      result = Rust.eval!(%{code: "test", value: 42})
      assert is_map(result)
      assert result["status"] == "evaluated"
    end
  end

  describe "to_lux_value/1" do
    test "converts nil" do
      assert {:ok, %{"type" => "Nil"}} = Rust.to_lux_value(nil)
    end

    test "converts booleans" do
      assert {:ok, %{"type" => "Bool"}} = Rust.to_lux_value(true)
      assert {:ok, %{"type" => "Bool"}} = Rust.to_lux_value(false)
    end

    test "converts integers" do
      assert {:ok, %{"type" => "Int", "value" => 42}} = Rust.to_lux_value(42)
    end

    test "converts floats" do
      assert {:ok, %{"type" => "Float"}} = Rust.to_lux_value(3.14)
    end

    test "converts strings" do
      assert {:ok, %{"type" => "Str", "value" => "hello"}} = Rust.to_lux_value("hello")
    end

    test "converts lists" do
      assert {:ok, %{"type" => "List", "value" => [1, 2, 3]}} = Rust.to_lux_value([1, 2, 3])
    end

    test "converts maps" do
      assert {:ok, %{"type" => "Map"}} = Rust.to_lux_value(%{key: "value"})
    end
  end

  describe "from_lux_value/1" do
    test "converts simple lux value" do
      assert {:ok, 42} = Rust.from_lux_value(%{"type" => "Int", "value" => 42})
    end

    test "converts string lux value" do
      assert {:ok, "hello"} = Rust.from_lux_value(%{"type" => "Str", "value" => "hello"})
    end

    test "rejects invalid format" do
      assert {:error, %Error{kind: :type_error}} = Rust.from_lux_value("not a map")
    end
  end

  describe "version/0" do
    test "returns the Rust core version" do
      assert Rust.version() == "0.1.0"
    end
  end

  describe "rust_path/0" do
    test "returns path to priv/rust directory" do
      path = Rust.rust_path()
      assert is_binary(path)
      assert path |> Path.basename() == "rust"
    end
  end

  describe "available?/0" do
    test "returns true when rust directory and Cargo.toml exist" do
      assert Rust.available?() == true
    end
  end

  describe "Error module" do
    test "creates error with kind and message" do
      err = Error.new(:type_error, "invalid type")
      assert err.kind == :type_error
      assert err.message == "invalid type"
    end

    test "creates error from string" do
      err = Error.from_string("something broke")
      assert err.kind == :runtime_error
      assert err.message == "something broke"
    end

    test "formats error message with kind" do
      err = Error.new(:ffi_error, "connection lost")
      assert String.starts_with?(to_string(err), "ffi_error:")
    end

    test "implements String.Chars" do
      err = Error.new(:runtime_error, "computation failed")
      assert to_string(err) == "runtime_error: computation failed"
    end
  end
end
