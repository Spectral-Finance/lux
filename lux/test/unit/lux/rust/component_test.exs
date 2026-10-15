defmodule Lux.Rust.ComponentTest do
  use ExUnit.Case, async: true
  alias Lux.Rust.Component

  test "defines Rust-backed Prism and Beam components with async lifecycle metadata" do
    {:ok, comp} =
      Component.define_component(%{
        name: "OrderbookMatcherPrism",
        kind: :prism,
        crate: "lux_orderbook_nif",
        entrypoint: "match_orders",
        async: true
      })

    assert comp.kind == :prism
    assert comp.async_runtime == true
    assert comp.lifecycle == :initialized
  end
end
