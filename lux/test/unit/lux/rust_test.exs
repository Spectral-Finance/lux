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

    test "returns error for multiple operators" do
      assert {:error, msg} = eval("1 + 2 + 3")
      assert msg =~ "Multiple operators"
    end

    test "returns error for mixed operators" do
      assert {:error, msg} = eval("2 * 3 + 4")
      assert msg =~ "Multiple operators"
    end

    test "returns error for undefined variable" do
      assert {:error, msg} = eval("undefined_var")
      assert msg =~ "Variable not found"
    end

    test "returns error for type mismatch" do
      assert {:error, msg} = eval("x + y", variables: %{x: 10, y: "string"})
      assert msg =~ "Expected number"
    end

    test "handles negative numbers" do
      assert {:ok, -5} = eval("x - y", variables: %{x: 5, y: 10})
    end

    test "handles float results" do
      assert {:ok, result} = eval("x / y", variables: %{x: 5, y: 2})
      assert_in_delta result, 2.5, 0.001
    end

    test "returns error for empty string" do
      assert {:error, _} = eval("")
    end

    test "returns error for whitespace only" do
      assert {:error, _} = eval("   ")
    end

    test "returns error for overflow (infinity)" do
      # 1e308 * 10 exceeds f64 max
      assert {:error, msg} = eval("x * y", variables: %{x: 1.0e308, y: 10.0})
      assert msg =~ "overflow" or msg =~ "invalid"
    end

    test "returns error for code exceeding max length" do
      # Max is 64KB, create 65KB string
      long_code = String.duplicate("x", 65 * 1024)
      assert {:error, msg} = eval(long_code, variables: %{x: 1})
      assert msg =~ "exceeds maximum length"
    end

    test "returns error for too many variables" do
      # Max is 1000 variables
      vars = for i <- 1..1001, into: %{}, do: {"var#{i}", i}
      assert {:error, msg} = eval("x", variables: vars)
      assert msg =~ "Too many variables"
    end

    test "handles integer overflow gracefully" do
      # i64 MAX + 1 should return float (overflow)
      assert {:ok, result} = eval("9223372036854775807 + 1")
      assert is_float(result)
    end

    test "preserves integer precision when possible" do
      # Large but valid integer
      assert {:ok, 9_223_372_036_854_775_807} = eval("9223372036854775806 + 1")
    end

    test "supports integer keys in variables" do
      assert {:ok, 456} = eval("123", variables: %{123 => 456})
    end

    test "exact division returns integer" do
      assert {:ok, 5} = eval("10 / 2")
    end

    test "non-exact division returns float" do
      assert {:ok, result} = eval("5 / 2")
      assert is_float(result)
      assert_in_delta result, 2.5, 0.001
    end

    # Edge cases discovered during exhaustive testing

    test "handles i64 MIN / -1 overflow without panic" do
      # i64 MIN / -1 would overflow to i64 MAX + 1, should return float
      assert {:ok, result} = eval("x / y", variables: %{x: -9_223_372_036_854_775_808, y: -1})
      assert is_float(result)
      assert_in_delta result, 9.223372036854776e18, 1.0e10
    end

    test "requires spaces around operators" do
      # Operators without spaces are not parsed
      assert {:error, msg} = eval("1+2")
      assert msg =~ "Cannot evaluate"
    end

    test "returns error for incomplete expressions" do
      assert {:error, _} = eval("+ 1")
      assert {:error, _} = eval("1 +")
      assert {:error, _} = eval("+")
    end

    test "supports unicode variable names" do
      assert {:ok, 42} = eval("日本語", variables: %{"日本語" => 42})
      assert {:ok, 3} = eval("α + β", variables: %{"α" => 1, "β" => 2})
    end

    test "handles negative number literals" do
      assert {:ok, -1} = eval("-1")
      assert {:ok, 0} = eval("-0")
    end

    test "handles double negation in subtraction" do
      assert {:ok, 2} = eval("1 - -1")
    end

    test "returns error for non-numeric type in arithmetic" do
      assert {:error, msg} = eval("x + 1", variables: %{x: nil})
      assert msg =~ "Expected number"

      assert {:error, msg} = eval("x + 1", variables: %{x: true})
      assert msg =~ "Expected number"

      assert {:error, msg} = eval("x + 1", variables: %{x: false})
      assert msg =~ "Expected number"
    end

    test "returns list and map values directly" do
      assert {:ok, [1, 2, 3]} = eval("x", variables: %{x: [1, 2, 3]})
      assert {:ok, %{"a" => 1}} = eval("x", variables: %{x: %{a: 1}})
    end

    test "returns error for maps with non-string keys in variable values" do
      # JSON compatibility: only string/atom keys supported
      assert {:error, _} = eval("x", variables: %{x: %{1 => "one"}})
      assert {:error, _} = eval("x", variables: %{x: %{{:a, :b} => 1}})
    end

    test "enforces collection size limit" do
      # 10000 elements should work
      big_list = Enum.to_list(1..10_000)
      assert {:ok, result} = eval("x", variables: %{x: big_list})
      assert length(result) == 10_000

      # 10001 elements should fail
      too_big = Enum.to_list(1..10_001)
      assert {:error, _} = eval("x", variables: %{x: too_big})
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

    test "converts nil to JSON null" do
      assert {:ok, "null"} = to_json(nil)
    end

    test "converts empty collections to JSON" do
      assert {:ok, "[]"} = to_json([])
      assert {:ok, "{}"} = to_json(%{})
    end

    test "converts nested structures to JSON" do
      nested = %{"users" => [%{"name" => "Alice"}, %{"name" => "Bob"}]}
      assert {:ok, json} = to_json(nested)
      assert json =~ "Alice"
      assert json =~ "Bob"
    end

    test "converts tuple to JSON array" do
      assert {:ok, "[1,2,3]"} = to_json({1, 2, 3})
    end

    # Edge cases for JSON serialization

    test "converts unicode strings to JSON" do
      assert {:ok, json} = to_json("日本語")
      assert json == ~s("日本語")
    end

    test "escapes special characters in JSON" do
      assert {:ok, json} = to_json("hello\nworld")
      assert json == ~s("hello\\nworld")
    end

    test "converts deeply nested structures" do
      nested = %{"a" => %{"b" => %{"c" => [1, 2, 3]}}}
      assert {:ok, json} = to_json(nested)
      assert json =~ "\"a\""
      assert json =~ "\"b\""
      assert json =~ "\"c\""
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

    test "returns error for empty string" do
      assert {:error, _} = from_json("")
    end

    test "parses empty object" do
      assert {:ok, %{}} = from_json("{}")
    end

    test "parses empty array" do
      assert {:ok, []} = from_json("[]")
    end

    # Edge cases for JSON parsing

    test "parses JSON null" do
      assert {:ok, nil} = from_json("null")
    end

    test "returns error for whitespace-only input" do
      assert {:error, _} = from_json("   ")
      assert {:error, _} = from_json("\t\n")
    end

    test "parses unicode strings" do
      assert {:ok, "日本語"} = from_json(~s("日本語"))
      assert {:ok, "αβγ"} = from_json(~s("αβγ"))
    end

    test "parses escape sequences" do
      assert {:ok, "hello\nworld"} = from_json(~s("hello\\nworld"))
      assert {:ok, "tab\there"} = from_json(~s("tab\\there"))
      assert {:ok, "quote\""} = from_json(~s("quote\\""))
    end

    test "parses JSON primitives" do
      assert {:ok, true} = from_json("true")
      assert {:ok, false} = from_json("false")
      assert {:ok, 42} = from_json("42")
      assert {:ok, 3.14} = from_json("3.14")
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

      assert 15 = result
    end

    test "supports variable bindings" do
      result =
        rust variables: %{x: 21} do
          ~RS"x * 2"
        end

      assert 42 = result
    end
  end

  describe "sigil_RS/2" do
    test "returns the string unchanged" do
      assert ~RS"x + y" == "x + y"
    end
  end
end
