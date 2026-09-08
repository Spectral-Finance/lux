defmodule Lux.Integration.RustComponentsTest do
  use IntegrationCase, async: false

  @moduletag :rust
  @moduletag :integration

  alias Lux.Rust.Component

  setup do
    unless Lux.Rust.available?() do
      {:skip, "lux_core NIF not loaded"}
    else
      :ok
    end
  end

  test "Lux.Prism.run/2 dispatches {:rust, id} handlers" do
    {:ok, prism} = Component.view("echo")
    assert %Lux.Prism{handler: {:rust, "echo"}} = prism
    assert {:ok, %{"k" => 1}} = Lux.Prism.run(prism, %{"k" => 1})
  end

  test "file-style rust prism id runs through Component" do
    assert {:ok, %{"n" => 42}} = Component.run("echo.rs", %{"n" => 42})
  end

  test "fib rust prism via Component.run" do
    assert {:ok, 55} = Component.run("fib", 10)
  end

  test "Beam.view of sequence is a %Lux.Beam{}" do
    assert {:ok, %Lux.Beam{}} = Component.view("sequence")
    assert {:ok, _} = Component.run("sequence", "lux")
  end

  test "async sleep prism returns ok" do
    if Component.async_available?() do
      assert {:ok, %{"ok" => true}} = Component.run_async("sleep", %{"ms" => 5})
    end
  end

  test "unknown component is an error, not a panic" do
    assert {:error, _} = Component.run("missing.rs", %{})
  end
end
