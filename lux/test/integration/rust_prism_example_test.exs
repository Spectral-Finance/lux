defmodule Lux.Integration.RustPrismExampleTest do
  use IntegrationCase, async: false

  @moduletag :rust
  @moduletag :integration

  setup do
    unless Lux.Rust.available?() do
      {:skip, "lux_core NIF not loaded"}
    else
      :ok
    end
  end

  test "Lux.Prism.run dispatches {:rust, id} handlers" do
    {:ok, prism} = Lux.Rust.Component.view("echo")
    assert %Lux.Prism{handler: {:rust, "echo"}} = prism
    assert {:ok, %{"hello" => "world"}} = Lux.Prism.run(prism, %{"hello" => "world"})
  end

  test "file-style rust prism id runs through Component" do
    assert {:ok, %{"n" => 42}} = Lux.Rust.Component.run("echo.rs", %{"n" => 42})
  end

  test "fib rust prism via Component.run" do
    assert {:ok, 55} = Lux.Rust.Component.run("fib", 10)
  end
end
