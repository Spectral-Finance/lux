defmodule Lux.RustTest do
  use ExUnit.Case, async: true

  alias Lux.Rust

  describe "Rust runtime bridge" do
    test "ping/0 verifies runtime connectivity" do
      assert {:ok, %{"status" => "pong", "runtime" => "rust"}} = Rust.ping()
    end

    test "invoke/2 echoes JSON payloads successfully" do
      payload = %{"test" => "data", "value" => 123}
      assert {:ok, ^payload} = Rust.invoke("echo", payload)
    end

    test "invoke/2 returns error on nonexistent function" do
      assert {:error, "Function not found: nonexistent_fn"} = Rust.invoke("nonexistent_fn", %{})
    end
  end
end
