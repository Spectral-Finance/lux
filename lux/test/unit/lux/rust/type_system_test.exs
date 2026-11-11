defmodule Lux.Rust.TypeSystemTest do
  use ExUnit.Case, async: true
  alias Lux.Rust.TypeSystem

  test "maps primitives, vectors, options, and structs and roundtrips Serde enums" do
    schema = {:struct, %{id: :u64, tags: {:vec, :string}, score: {:option, :f64}}}
    assert {:ok, %{id: :non_neg_integer, tags: {:list, :binary}, score: {:nullable, :float}}} =
             TypeSystem.to_elixir_type(schema)

    assert {:ok, %{"LimitOrder" => %{price: 2500.0}}} =
             TypeSystem.encode_serde_enum({:LimitOrder, %{price: 2500.0}})

    assert {:ok, {:LimitOrder, %{price: 2500.0}}} =
             TypeSystem.decode_serde_enum(%{"LimitOrder" => %{price: 2500.0}})
  end
end
