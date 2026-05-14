defmodule Lux.Rust.FixturesTest do
  use UnitCase, async: true

  alias Lux.Rust.Fixtures

  describe "manifest/2" do
    test "records stable file metadata" do
      manifest =
        Fixtures.manifest(%{"data/input.json" => "{\"ok\":true}"},
          generated_at: ~U[2026-01-01 00:00:00Z]
        )

      assert manifest.format == 1
      assert manifest.generated_at == "2026-01-01T00:00:00Z"
      assert [%{path: "data/input.json", bytes: 11, sha256: sha}] = manifest.files
      assert byte_size(sha) == 64
    end

    test "rejects traversal paths" do
      assert_raise ArgumentError, fn ->
        Fixtures.manifest(%{"../secret" => "no"})
      end
    end
  end

  describe "write helpers" do
    test "writes fixtures and manifest" do
      root = tmp_dir()

      manifest =
        Fixtures.write_manifest!(root, %{"payloads/message.txt" => "hello"},
          generated_at: ~U[2026-01-01 00:00:00Z]
        )

      assert File.read!(Path.join(root, "payloads/message.txt")) == "hello"
      assert File.exists?(manifest.manifest_path)
      assert manifest.files |> hd() |> Map.fetch!(:path) == "payloads/message.txt"
    end

    test "creates a minimal Cargo project" do
      root = tmp_dir()

      assert Fixtures.create_project!(root, name: "demo_fixture") == root
      assert File.read!(Path.join(root, "Cargo.toml")) =~ "name = \"demo_fixture\""
      assert File.exists?(Path.join(root, "src/lib.rs"))
    end
  end

  defp tmp_dir do
    path = Path.join(System.tmp_dir!(), "lux-rust-fixtures-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end
end
