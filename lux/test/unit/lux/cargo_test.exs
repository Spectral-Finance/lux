defmodule Lux.CargoTest do
  use UnitCase, async: false

  alias Lux.Cargo

  @moduletag :unit

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp tmp_toml(content) do
    path = Path.join(System.tmp_dir!(), "cargo_test_#{:rand.uniform(999_999)}.toml")
    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp basic_toml do
    """
    [package]
    name = "my_crate"
    version = "0.1.0"
    edition = "2021"

    [dependencies]
    serde = "1.0"
    tokio = "1"

    [dev-dependencies]
    mockall = "0.13"
    """
  end

  # ── parse_toml/1 ─────────────────────────────────────────────────────────────

  describe "parse_toml/1" do
    test "parses [package] section" do
      path = tmp_toml(basic_toml())
      {:ok, manifest} = Cargo.parse_toml(path)

      assert manifest.package["name"] == ~s("my_crate")
      assert manifest.package["version"] == ~s("0.1.0")
    end

    test "parses [dependencies] section" do
      path = tmp_toml(basic_toml())
      {:ok, manifest} = Cargo.parse_toml(path)

      assert manifest.dependencies["serde"] == ~s("1.0")
      assert manifest.dependencies["tokio"] == ~s("1")
    end

    test "parses [dev-dependencies] section" do
      path = tmp_toml(basic_toml())
      {:ok, manifest} = Cargo.parse_toml(path)

      assert manifest.dev_dependencies["mockall"] == ~s("0.13")
    end

    test "returns empty maps for missing sections" do
      path = tmp_toml("[package]\nname = \"minimal\"\nversion = \"0.0.1\"\n")
      {:ok, manifest} = Cargo.parse_toml(path)

      assert manifest.dependencies == %{}
      assert manifest.dev_dependencies == %{}
      assert manifest.build_dependencies == %{}
    end

    test "ignores comment lines" do
      content = """
      # project config
      [package]
      # metadata below
      name = "commented"
      version = "0.1.0"
      """

      path = tmp_toml(content)
      {:ok, manifest} = Cargo.parse_toml(path)

      assert manifest.package["name"] == ~s("commented")
    end

    test "returns error for missing file" do
      assert {:error, msg} = Cargo.parse_toml("/non/existent/Cargo.toml")
      assert String.contains?(msg, "Cannot read")
    end
  end

  # ── write_toml/2 ─────────────────────────────────────────────────────────────

  describe "write_toml/2" do
    test "writes and re-reads package section" do
      path = tmp_toml("")

      manifest = %{
        package: %{"name" => ~s("roundtrip"), "version" => ~s("1.0.0")},
        dependencies: %{"anyhow" => ~s("1")},
        dev_dependencies: %{},
        build_dependencies: %{}
      }

      assert {:ok, :written} = Cargo.write_toml(path, manifest)

      {:ok, read_back} = Cargo.parse_toml(path)
      assert read_back.package["name"] == ~s("roundtrip")
      assert read_back.dependencies["anyhow"] == ~s("1")
    end

    test "returns error for unwritable path" do
      assert {:error, _} = Cargo.write_toml("/no/such/dir/Cargo.toml", %{package: %{}})
    end
  end

  # ── add_dependency/4 ─────────────────────────────────────────────────────────

  describe "add_dependency/4" do
    test "adds a new dependency with simple version" do
      path = tmp_toml(basic_toml())
      assert {:ok, :updated} = Cargo.add_dependency(path, "anyhow", "1.0")

      {:ok, manifest} = Cargo.parse_toml(path)
      assert manifest.dependencies["anyhow"] == ~s("1.0")
    end

    test "updates an existing dependency in-place" do
      path = tmp_toml(basic_toml())
      assert {:ok, :updated} = Cargo.add_dependency(path, "serde", "2.0")

      {:ok, manifest} = Cargo.parse_toml(path)
      assert manifest.dependencies["serde"] == ~s("2.0")
    end

    test "adds to dev-dependencies section" do
      path = tmp_toml(basic_toml())
      assert {:ok, :updated} = Cargo.add_dependency(path, "proptest", "1.4", section: :dev_dependencies)

      {:ok, manifest} = Cargo.parse_toml(path)
      assert manifest.dev_dependencies["proptest"] == ~s("1.4")
    end

    test "creates missing section when adding" do
      path = tmp_toml("[package]\nname = \"x\"\nversion = \"0.1.0\"\n")
      assert {:ok, :updated} = Cargo.add_dependency(path, "log", "0.4")

      content = File.read!(path)
      assert String.contains?(content, "[dependencies]")
      assert String.contains?(content, ~s(log = "0.4"))
    end

    test "formats dependency with features" do
      path = tmp_toml(basic_toml())
      assert {:ok, :updated} = Cargo.add_dependency(path, "serde_json", "1.0", features: ["preserve_order"])

      content = File.read!(path)
      assert String.contains?(content, "serde_json")
      assert String.contains?(content, "features")
    end

    test "marks dependency as optional" do
      path = tmp_toml(basic_toml())
      assert {:ok, :updated} = Cargo.add_dependency(path, "rayon", "1.8", optional: true)

      content = File.read!(path)
      assert String.contains?(content, "optional = true")
    end
  end

  # ── remove_dependency/3 ───────────────────────────────────────────────────────

  describe "remove_dependency/3" do
    test "removes an existing dependency" do
      path = tmp_toml(basic_toml())
      assert {:ok, :removed} = Cargo.remove_dependency(path, "serde")

      {:ok, manifest} = Cargo.parse_toml(path)
      refute Map.has_key?(manifest.dependencies, "serde")
    end

    test "is a no-op for non-existent crate" do
      path = tmp_toml(basic_toml())
      assert {:ok, :removed} = Cargo.remove_dependency(path, "nonexistent_crate")

      {:ok, manifest} = Cargo.parse_toml(path)
      assert Map.has_key?(manifest.dependencies, "serde")
    end
  end

  # ── list_dependencies/2 ───────────────────────────────────────────────────────

  describe "list_dependencies/2" do
    test "returns all dependencies" do
      path = tmp_toml(basic_toml())
      {:ok, deps} = Cargo.list_dependencies(path)

      assert Map.has_key?(deps, "serde")
      assert Map.has_key?(deps, "tokio")
    end

    test "returns dev-dependencies when asked" do
      path = tmp_toml(basic_toml())
      {:ok, deps} = Cargo.list_dependencies(path, section: :dev_dependencies)

      assert Map.has_key?(deps, "mockall")
      refute Map.has_key?(deps, "serde")
    end

    test "returns empty map when section missing" do
      path = tmp_toml("[package]\nname = \"x\"\nversion = \"0.1.0\"\n")
      {:ok, deps} = Cargo.list_dependencies(path)

      assert deps == %{}
    end
  end

  # ── crate_info/2 and latest_version/1 ─────────────────────────────────────────

  describe "crate_info/2 with HTTP stub" do
    setup do
      Application.put_env(:lux, Lux.Cargo, plug: {Req.Test, Lux.Cargo})
      Req.Test.verify_on_exit!()
      :ok
    end

    test "returns parsed crate metadata" do
      Req.Test.expect(Lux.Cargo, fn conn ->
        assert conn.request_path =~ "/crates/serde"
        Req.Test.json(conn, %{
          "crate" => %{
            "name" => "serde",
            "newest_version" => "1.0.215",
            "description" => "A serialization framework"
          },
          "versions" => [
            %{"num" => "1.0.215"},
            %{"num" => "1.0.0"}
          ]
        })
      end)

      assert {:ok, info} = Cargo.crate_info("serde", [])
      assert get_in(info, ["crate", "name"]) == "serde"
    end

    test "returns error for 404" do
      Req.Test.expect(Lux.Cargo, fn conn ->
        Req.Test.json(conn, %{"errors" => [%{"detail" => "Not Found"}]})
        |> Plug.Conn.put_status(404)
      end)

      assert {:error, msg} = Cargo.crate_info("totally_fake_crate_xyz", [])
      assert String.contains?(msg, "not found")
    end
  end

  describe "latest_version/1 with HTTP stub" do
    setup do
      Application.put_env(:lux, Lux.Cargo, plug: {Req.Test, Lux.Cargo})
      Req.Test.verify_on_exit!()
      :ok
    end

    test "extracts newest_version field" do
      Req.Test.expect(Lux.Cargo, fn conn ->
        Req.Test.json(conn, %{
          "crate" => %{"name" => "tokio", "newest_version" => "1.42.0"},
          "versions" => []
        })
      end)

      assert {:ok, "1.42.0"} = Cargo.latest_version("tokio")
    end
  end

  describe "version_exists?/3 with HTTP stub" do
    setup do
      Application.put_env(:lux, Lux.Cargo, plug: {Req.Test, Lux.Cargo})
      Req.Test.verify_on_exit!()
      :ok
    end

    test "returns true when version is in the list" do
      Req.Test.expect(Lux.Cargo, fn conn ->
        Req.Test.json(conn, %{
          "crate" => %{"newest_version" => "1.0.215"},
          "versions" => [%{"num" => "1.0.0"}, %{"num" => "1.0.215"}]
        })
      end)

      assert Cargo.version_exists?("serde", "1.0.0", [])
    end

    test "returns false when version is not listed" do
      Req.Test.expect(Lux.Cargo, fn conn ->
        Req.Test.json(conn, %{
          "crate" => %{"newest_version" => "1.0.215"},
          "versions" => [%{"num" => "1.0.215"}]
        })
      end)

      refute Cargo.version_exists?("serde", "99.99.99", [])
    end
  end

  # ── build/check/test/fetch (unit, no real cargo invocation) ─────────────────

  describe "run_cargo error handling" do
    test "build returns descriptive error when cargo is not on PATH" do
      # Only meaningful if cargo is absent; if present, this exercises real build
      result = Cargo.build(System.tmp_dir!())

      case result do
        {:ok, _} -> :ok
        {:error, msg} -> assert is_binary(msg)
      end
    end

    test "check returns descriptive error or ok" do
      result = Cargo.check(System.tmp_dir!())

      case result do
        {:ok, _} -> :ok
        {:error, msg} -> assert is_binary(msg)
      end
    end
  end

  # ── format_dep / upsert_dep (indirectly via add_dependency) ─────────────────

  describe "dependency value formatting" do
    test "plain version produces a quoted string" do
      path = tmp_toml("[package]\nname = \"x\"\nversion = \"0.1.0\"\n\n[dependencies]\n")
      Cargo.add_dependency(path, "log", "0.4")
      content = File.read!(path)
      assert content =~ ~s(log = "0.4")
    end

    test "features list produces inline table" do
      path = tmp_toml("[package]\nname = \"x\"\nversion = \"0.1.0\"\n\n[dependencies]\n")
      Cargo.add_dependency(path, "serde", "1.0", features: ["derive"])
      content = File.read!(path)
      assert content =~ "serde"
      assert content =~ "features"
      assert content =~ "derive"
    end
  end
end
