defmodule Lux.Rust.ComponentRegistryTest do
  use ExUnit.Case

  @moduletag :unit

  alias Lux.Rust.ComponentRegistry

  defmodule SampleComponent do
    use Lux.Rust.Component,
      type: :prism,
      name: "Sample",
      description: "For testing registry"

    @impl true
    def handle(_params, _ctx), do: {:ok, %{}}
  end

  setup do
    {:ok, pid} = ComponentRegistry.start_link()
    on_exit(fn -> Process.alive?(pid) && GenServer.stop(pid) end)
    :ok
  end

  test "register and list components" do
    assert :ok = ComponentRegistry.register(SampleComponent)
    components = ComponentRegistry.list()
    assert length(components) == 1
    assert hd(components).name == "Sample"
    assert hd(components).type == :prism
  end

  test "get component info" do
    ComponentRegistry.register(SampleComponent)
    assert {:ok, info} = ComponentRegistry.info(SampleComponent)
    assert info.module == SampleComponent
    assert info.description == "For testing registry"
  end

  test "info returns error for unknown module" do
    assert {:error, :not_found} = ComponentRegistry.info(NonExistent)
  end

  test "available? checks NIF status" do
    ComponentRegistry.register(SampleComponent)
    assert ComponentRegistry.available?(SampleComponent) == true
  end
end
