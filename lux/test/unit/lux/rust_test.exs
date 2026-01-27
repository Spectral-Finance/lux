defmodule Lux.RustTest do
  use UnitCase, async: true

  import Lux.Rust

  require Lux.Rust

  describe "eval/2" do
    test "evaluates simple arithmetic expressions" do
      assert {:ok, 42} = eval("40 + 2")
      assert {:ok, 38} = eval("40 - 2")
      assert {:ok, 80} = eval("40 * 2")
      assert {:ok, 20} = eval("40 / 2")
    end

    test "evaluates code with variable bindings" do
      assert {:ok, 42} = eval("x + y", variables: %{x: 40, y: 2})
      assert {:ok, 100} = eval("x * y", variables: %{x: 10, y: 10})
    end

    test "supports atom keys in variables" do
      assert {:ok, 42} = eval("x + y", variables: %{x: 40, y: 2})
    end

    test "returns variable value directly" do
      assert {:ok, 42} = eval("x", variables: %{x: 42})
      assert {:ok, "hello"} = eval("name", variables: %{name: "hello"})
    end

    test "handles integer literals" do
      assert {:ok, 123} = eval("123")
    end

    test "handles float literals" do
      assert {:ok, result} = eval("3.14")
      assert_in_delta result, 3.14, 0.001
    end

    test "returns error for division by zero" do
      assert {:error, _} = eval("x / y", variables: %{x: 10, y: 0})
    end
  end

  describe "eval!/2" do
    test "returns result directly on success" do
      assert 42 = eval!("x + y", variables: %{x: 40, y: 2})
    end

    test "raises error on failure" do
      assert_raise RuntimeError, fn ->
        eval!("undefined_var")
      end
    end
  end

  describe "to_json/1" do
    test "converts map to JSON" do
      assert {:ok, json} = to_json(%{"name" => "test", "count" => 42})
      assert is_binary(json)
      assert String.contains?(json, "name")
      assert String.contains?(json, "test")
    end

    test "converts list to JSON" do
      assert {:ok, "[1,2,3]"} = to_json([1, 2, 3])
    end

    test "converts primitives to JSON" do
      assert {:ok, "42"} = to_json(42)
      assert {:ok, "true"} = to_json(true)
      assert {:ok, ~s("hello")} = to_json("hello")
    end
  end

  describe "from_json/1" do
    test "parses JSON object" do
      json = ~s({"name":"test","count":42})
      assert {:ok, result} = from_json(json)
      assert result["name"] == "test"
      assert result["count"] == 42
    end

    test "parses JSON array" do
      assert {:ok, [1, 2, 3]} = from_json("[1,2,3]")
    end

    test "returns error for invalid JSON" do
      assert {:error, _} = from_json("not valid json")
    end
  end

  describe "version/0" do
    test "returns version string" do
      version = version()
      assert is_binary(version)
      assert version =~ ~r/^\d+\.\d+\.\d+$/
    end
  end

  describe "health_check/0" do
    test "returns health status" do
      assert {:ok, result} = health_check()
      assert result["status"] == "ok"
      assert result["language"] == "rust"
      assert is_binary(result["version"])
    end
  end

  describe "module_path/0" do
    test "returns the rust module path" do
      assert String.ends_with?(module_path(), "priv/rust")
    end
  end

  describe "rust/2 macro" do
    test "executes simple Rust expressions" do
      result =
        rust do
          ~RS"10 + 5"
        end

      assert {:ok, 15} = result
    end

    test "supports variable bindings" do
      result =
        rust variables: %{x: 21} do
          ~RS"x * 2"
        end

      assert {:ok, 42} = result
    end
  end

  describe "sigil_RS/2" do
    test "returns the string unchanged" do
      assert ~RS"x + y" == "x + y"
    end
  end
end
