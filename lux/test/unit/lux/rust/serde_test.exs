defmodule Lux.Rust.SerdeTest do
  use ExUnit.Case, async: true
  alias Lux.Rust.Serde

  test "generates Serde Rust struct definition and serializes tagged enums" do
    {:ok, rust_code} =
      Serde.define_rust_struct("OrderSignal", [
        {:symbol, "String"},
        {:price, "f64"},
        {:size, "f64"}
      ])

    assert rust_code =~ "pub struct OrderSignal"
    assert rust_code =~ "pub price: f64"

    {:ok, tagged} = Serde.to_serde_tagged({:LimitOrder, %{price: 2500.0, size: 1.5}})
    assert tagged["LimitOrder"].price == 2500.0
  end
end
