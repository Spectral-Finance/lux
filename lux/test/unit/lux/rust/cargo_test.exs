defmodule Lux.Rust.CargoTest do
  use ExUnit.Case, async: true
  alias Lux.Rust.Cargo

  test "renders Cargo.toml manifest and computes deterministic build cache key" do
    {:ok, toml} =
      Cargo.render_cargo_toml(%{
        name: "lux_crypto_nif",
        version: "0.2.0",
        dependencies: %{"rustler" => "0.34.0", "sha2" => "0.10"}
      })

    assert toml =~ ~s(name = "lux_crypto_nif")
    assert toml =~ ~s(sha2 = "0.10")

    key = Cargo.cache_key(toml, "x86_64-pc-windows-msvc")
    assert byte_size(key) == 64
  end
end
