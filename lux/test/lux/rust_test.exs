defmodule Lux.RustTest do
  use ExUnit.Case, async: true

  alias Lux.Native

  test "list_components/0" do
    components = Native.list_components()
    assert "Echo" in components
  end

  test "call_component/2 - Math" do
    input = %{"op" => "add", "a" => 1, "b" => 2}
    assert Native.call_component("Math", input) == 3
  end
end
