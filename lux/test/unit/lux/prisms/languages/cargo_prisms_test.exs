defmodule Lux.Prisms.Languages.CargoPrismsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Languages.Rust.Cargo.AddDependencyPrism
  alias Lux.Prisms.Languages.Rust.Cargo.AuditPrism
  alias Lux.Prisms.Languages.Rust.Cargo.BuildPrism
  alias Lux.Prisms.Languages.Rust.Cargo.CachePrism
  alias Lux.Prisms.Languages.Rust.Cargo.RemoveDependencyPrism

  describe "AuditPrism" do
    test "audits dependencies in default Cargo.toml" do
      assert {:ok, result} = AuditPrism.handler(%{}, %{})
      assert result.status == "audited"
      assert result.dependencies_count > 0
    end
  end

  describe "CachePrism" do
    test "inspects Cargo cache" do
      assert {:ok, result} = CachePrism.handler(%{}, %{})
      assert is_binary(result.cargo_home)
    end
  end

  describe "BuildPrism" do
    test "compiles Rust project" do
      assert {:ok, result} = BuildPrism.handler(%{"release" => true}, %{})
      assert result.compiled == true
      assert result.status == "success"
    end
  end

  describe "AddDependencyPrism & RemoveDependencyPrism" do
    test "adds and removes a temporary crate" do
      add_res = AddDependencyPrism.handler(%{"crate" => "temp_crate", "version" => "0.1.0"}, %{})
      assert {:ok, res} = add_res
      assert res.status == "added"

      rem_res = RemoveDependencyPrism.handler(%{"crate" => "temp_crate"}, %{})
      assert {:ok, rres} = rem_res
      assert rres.status == "removed"
    end
  end
end
