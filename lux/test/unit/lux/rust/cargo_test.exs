defmodule Lux.Rust.CargoTest do
  use ExUnit.Case, async: true
  alias Lux.Rust.Cargo

  test "generates Cargo.toml with feature flags and computes deterministic cache keys" do
    toml =
      Cargo.generate_cargo_toml(
        %{name: "lux_native", version: "0.2.0"},
        %{
          serde: %{version: "1.0", features: ["derive"]},
          tokio: "1.38"
        }
      )

    assert toml =~ ~s(name = "lux_native")
    assert toml =~ ~s(serde = { version = "1.0", features = ["derive"] })
    assert toml =~ ~s(tokio = "1.38")

    k1 = Cargo.compute_cache_key(toml, "lock-v1")
    k2 = Cargo.compute_cache_key(toml, "lock-v1")
    assert k1 == k2
    assert String.length(k1) == 64
  end
end
