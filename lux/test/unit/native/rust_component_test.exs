defmodule Lux.Native.RustComponentTest do
  use ExUnit.Case, async: true

  defmodule SampleRustPrism do
    use Lux.Native.RustComponent, name: "fast_matrix_prism"

    @impl true
    def invoke_native(%{"value" => v}), do: {:ok, %{"doubled" => v * 2}}
  end

  test "executes native component wrapper and records execution telemetry" do
    assert {:ok, %{component: "fast_matrix_prism", result: {:ok, %{"doubled" => 42}}}} =
             SampleRustPrism.run(%{"value" => 21})
  end
end
