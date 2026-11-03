defmodule Lux.Languages.RustTest do
  use UnitAPICase, async: true

  alias Lux.Rust
  alias Lux.Rust.Error, as: RustError
  alias Lux.Rust.Types

  require Lux.Rust
  import Lux.Rust

  describe "Lux.Rust.call/3" do
    test "executes math.add" do
      assert {:ok, 30.0} = Rust.call("math.add", %{"a" => 10.0, "b" => 20.0})
      assert {:ok, 15} = Rust.call("math.add", [1, 2, 3, 4, 5])
    end

    test "executes math.fibonacci" do
      assert {:ok, 0} = Rust.call("math.fibonacci", %{"n" => 0})
      assert {:ok, 1} = Rust.call("math.fibonacci", %{"n" => 1})
      assert {:ok, 55} = Rust.call("math.fibonacci", %{"n" => 10})
    end

    test "executes math.dot_product" do
      vec_a = [1.0, 2.0, 3.0]
      vec_b = [4.0, 5.0, 6.0]
      # 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32.0
      assert {:ok, 32.0} = Rust.call("math.dot_product", %{"a" => vec_a, "b" => vec_b})
    end

    test "executes string.to_uppercase" do
      assert {:ok, "HEAVY COMPUTATION"} = Rust.call("string.to_uppercase", "heavy computation")
    end

    test "handles function not found error" do
      assert {:error, %RustError{type: :function_not_found}} =
               Rust.call("unknown.func", %{})
    end

    test "handles invalid argument error" do
      assert {:error, %RustError{type: :invalid_argument}} =
               Rust.call("math.fibonacci", %{"n" => -10})
    end
  end

  describe "~RS sigil and macro" do
    test "evaluates inline Rust macro with variable bindings" do
      result =
        rust variables: %{a: 5, b: 15} do
          ~RS"""
          pub fn main(args: Map) -> i64 {
              args["a"] + args["b"]
          }
          """
        end

      assert {:ok, 20} = result
    end
  end

  describe "Lux.Rust.Types" do
    test "converts complex Elixir structures to Rust-compatible terms" do
      data = %{
        symbol: :ETH,
        price: 3250.75,
        active: true,
        tags: [:crypto, :l1],
        metadata: [chain_id: 1]
      }

      converted = Types.to_rust_compatible(data)
      assert converted["symbol"] == "ETH"
      assert converted["price"] == 3250.75
      assert converted["active"] == true
      assert converted["tags"] == ["crypto", "l1"]
      assert converted["metadata"]["chain_id"] == 1
    end
  end
end
