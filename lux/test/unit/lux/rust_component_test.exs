defmodule Lux.Rust.ComponentTest do
  use UnitAPICase, async: false

  alias Lux.Rust.Component

  @moduletag :rust

  setup do
    unless Lux.Rust.available?() do
      {:skip, "lux_core NIF not loaded"}
    else
      :ok
    end
  end

  test "lists registered rust prisms and beams" do
    assert {:ok, list} = Component.list()
    ids =
      Enum.map(list, fn
        item when is_map(item) -> item["id"] || item[:id]
        other -> other
      end)

    assert "echo" in ids
    assert "sequence" in ids
  end

  test "view returns a prism with {:rust, id} handler" do
    assert {:ok, %Lux.Prism{} = view} = Component.view("echo")
    assert view.handler == {:rust, "echo"}
  end

  test "file-style ids resolve to the same component" do
    assert {:ok, a} = Component.view("echo")
    assert {:ok, b} = Component.view("echo.rs")
    assert a.handler == b.handler
  end

  test "lifecycle init then run then shutdown" do
    assert {:ok, _} = Component.init("echo")
    assert {:ok, out} = Component.run("echo", %{"n" => 1})
    assert out == %{"n" => 1}
    assert {:ok, _} = Component.status("echo")
    assert {:ok, _} = Component.shutdown("echo")
    assert {:error, _} = Component.run("echo", :ignored)
  end

  test "fib prism computes n=10" do
    assert {:ok, 55} = Component.run("fib", 10)
  end

  test "unknown component is a runtime error" do
    assert {:error, reason} = Component.run("does-not-exist", %{})
    assert reason != nil
  end

  test "async sleep prism uses tokio" do
    assert Component.async_available?()
    assert {:ok, result} = Component.run_async("sleep", %{"ms" => 1})
    assert result["ok"] == true or result[:ok] == true
  end

  test "beam sequence hashes then echoes" do
    assert {:ok, digest} = Component.run("sequence", "hello")
    assert is_integer(digest)
  end

  test "view of sequence is a Beam struct" do
    assert {:ok, %Lux.Beam{}} = Component.view("sequence")
  end
end
