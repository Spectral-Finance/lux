defmodule LuxTest do
  use UnitCase

  doctest Lux

  test "greets the world" do
    assert Lux.hello() == :world
  end
end
