defmodule Lux.Rust.ComponentTest do
  use ExUnit.Case, async: true
  alias Lux.Rust.Component

  test "defines Rust component, executes async payload, and manages lifecycle" do
    {:ok, comp} =
      Component.define(%{
        name: "OrderbookMatcherPrism",
        kind: :prism,
        crate_name: "lux_orderbook_matcher",
        entrypoint: "match_orders",
        async_runtime: :tokio
      })

    assert comp.lifecycle_state == :initialized
    assert comp.optimizations.zero_copy == true

    {:ok, exec_res} =
      Component.execute(comp, %{bid: 2500.0, ask: 2499.5}, fn _c, inp ->
        {:ok, %{matched: inp.bid >= inp.ask, spread: inp.bid - inp.ask}}
      end)

    assert exec_res.result.matched == true
    assert {:ok, stopped} = Component.shutdown(comp)
    assert {:error, :component_stopped} = Component.execute(stopped, %{}, fn _, _ -> {:ok, %{}} end)
  end
end
