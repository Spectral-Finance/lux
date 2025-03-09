defmodule Lux.Components.RustTest do
  use ExUnit.Case
  alias Lux.Components.Rust

  describe "echo component" do
    test "initializes successfully" do
      assert {:ok, component} = Rust.new("echo", %{})
      assert is_reference(component.reference)
    end

    test "processes input correctly" do
      {:ok, component} = Rust.new("echo", %{})
      input = %{"message" => "Hello, Rust!"}
      assert {:ok, ^input} = Rust.call(component, input)
    end

    test "cleans up resources" do
      {:ok, component} = Rust.new("echo", %{})
      assert :ok = Rust.terminate(component)
    end
  end
end
