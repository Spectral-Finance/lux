defmodule Lux.Rust.TypeSystemTest do
  use ExUnit.Case, async: false

  alias Lux.Rust.TypeSystem

  describe "elixir_to_rust_type/1 (#101)" do
    test "maps primitive and nested generic types to Rust signatures" do
      assert {:ok, "u64"} = TypeSystem.elixir_to_rust_type(:u64)
      assert {:ok, "Vec<String>"} = TypeSystem.elixir_to_rust_type({:vec, :string})
      assert {:ok, "Option<f64>"} = TypeSystem.elixir_to_rust_type({:option, :f64})
      assert {:ok, "Result<Vec<u8>, String>"} = TypeSystem.elixir_to_rust_type({:result, :binary, :string})
      assert {:ok, "(String, i64, bool)"} = TypeSystem.elixir_to_rust_type({:tuple, [:string, :i64, :bool]})
    end
  end

  describe "custom struct definition, Serde codegen, and bidirectional serialization (#101)" do
    test "defines custom struct, generates Serde code, and round-trips data" do
      assert {:ok, _def} =
               TypeSystem.define_struct(:order_ticket, "OrderTicket", [
                 {:symbol, :string},
                 {:quantity, :u64},
                 {:limit_price, {:option, :f64}},
                 {:tags, {:vec, :string}}
               ])

      assert {:ok, rust_code} = TypeSystem.generate_serde_rust_code(:order_ticket)
      assert rust_code =~ "pub struct OrderTicket"
      assert rust_code =~ "pub limit_price: Option<f64>"

      input = %{
        symbol: "ETH-USDC",
        quantity: 250,
        limit_price: 3150.25,
        tags: ["maker", "post_only"]
      }

      assert {:ok, %{json: json}} = TypeSystem.to_rust_payload(input, :order_ticket)
      assert {:ok, round_tripped} = TypeSystem.from_rust_payload(json, :order_ticket)
      assert round_tripped == input
    end
  end

  describe "custom enum definition and Serde tagged serialization (#101)" do
    test "defines custom enum with unit, tuple, and struct variants and round-trips payloads" do
      assert {:ok, _def} =
               TypeSystem.define_enum(:execution_signal, "ExecutionSignal", [
                 {:Heartbeat, :unit},
                 {:PriceTick, {:tuple, [:string, :f64]}},
                 {:FillOrder, {:struct, [{:order_id, :string}, {:filled_qty, :u64}]}}
               ])

      assert {:ok, enum_code} = TypeSystem.generate_serde_rust_code(:execution_signal)
      assert enum_code =~ "pub enum ExecutionSignal"
      assert enum_code =~ "PriceTick(String, f64)"

      tuple_val = %{variant: :PriceTick, data: {"BTC-USDC", 92500.5}}
      assert {:ok, %{json: tuple_json}} = TypeSystem.to_rust_payload(tuple_val, :execution_signal)
      assert {:ok, decoded_tuple} = TypeSystem.from_rust_payload(tuple_json, :execution_signal)
      assert decoded_tuple == tuple_val

      struct_val = %{variant: :FillOrder, data: %{order_id: "ord_99", filled_qty: 100}}
      assert {:ok, %{json: struct_json}} = TypeSystem.to_rust_payload(struct_val, :execution_signal)
      assert {:ok, decoded_struct} = TypeSystem.from_rust_payload(struct_json, :execution_signal)
      assert decoded_struct == struct_val
    end
  end
end
