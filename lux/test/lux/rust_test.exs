defmodule Lux.RustTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  describe "health_check/0" do
    test "returns status (healthy if loaded, error if not)" do
      result = Lux.Rust.health_check()
      assert match?({:ok, _} | {:error, _}, result)
    end
  end

  describe "available?/0" do
    test "returns a boolean" do
      assert is_boolean(Lux.Rust.available?())
    end
  end

  describe "version/0" do
    test "returns a map with version info" do
      version = Lux.Rust.version()
      assert is_map(version)
      assert Map.has_key?(version, "version")
    end
  end

  describe "module_path/0" do
    test "returns the Rust module path" do
      path = Lux.Rust.module_path()
      assert is_binary(path)
      assert String.ends_with?(path, "priv/rust")
    end
  end

  # The following tests require the Rust NIF to be compiled
  # They will be skipped if the NIF is not available

  describe "execute/2" do
    @describetag :integration

    test "executes add function" do
      case Lux.Rust.execute("add", %{a: 1, b: 2}) do
        {:ok, result} ->
          assert result == 3

        {:error, :nif_not_loaded} ->
          :ok
      end
    end

    test "executes multiply function" do
      case Lux.Rust.execute("multiply", %{a: 3, b: 4}) do
        {:ok, result} ->
          assert result == 12

        {:error, :nif_not_loaded} ->
          :ok
      end
    end

    test "executes concat function" do
      case Lux.Rust.execute("concat", %{a: "hello", b: " world"}) do
        {:ok, result} ->
          assert result == "hello world"

        {:error, :nif_not_loaded} ->
          :ok
      end
    end

    test "returns error for unknown function" do
      case Lux.Rust.execute("unknown_function", %{}) do
        {:error, msg} when is_binary(msg) ->
          assert String.contains?(msg, "Unknown function")

        {:error, :nif_not_loaded} ->
          :ok
      end
    end

    test "returns error for missing arguments" do
      case Lux.Rust.execute("add", %{a: 1}) do
        {:error, msg} when is_binary(msg) ->
          assert String.contains?(msg, "Missing")

        {:error, :nif_not_loaded} ->
          :ok
      end
    end
  end

  describe "eval/2" do
    @describetag :integration

    test "evaluates simple arithmetic" do
      case Lux.Rust.eval("2 + 3") do
        {:ok, result} ->
          assert result == 5

        {:error, :nif_not_loaded} ->
          :ok
      end
    end

    test "evaluates with variables" do
      case Lux.Rust.eval("x + y", variables: %{x: 10, y: 5}) do
        {:ok, result} ->
          assert result == 15

        {:error, :nif_not_loaded} ->
          :ok
      end
    end

    test "returns error for undefined variable" do
      case Lux.Rust.eval("undefined_var") do
        {:error, msg} when is_binary(msg) ->
          assert String.contains?(msg, "Undefined")

        {:error, :nif_not_loaded} ->
          :ok
      end
    end
  end

  describe "execute!/2" do
    @describetag :integration

    test "returns result directly on success" do
      if Lux.Rust.available?() do
        assert Lux.Rust.execute!("add", %{a: 1, b: 2}) == 3
      end
    end

    test "raises on error" do
      if Lux.Rust.available?() do
        assert_raise RuntimeError, ~r/Rust error/, fn ->
          Lux.Rust.execute!("unknown_function", %{})
        end
      end
    end
  end

  describe "eval!/2" do
    @describetag :integration

    test "returns result directly on success" do
      if Lux.Rust.available?() do
        assert Lux.Rust.eval!("2 * 3") == 6
      end
    end

    test "raises on error" do
      if Lux.Rust.available?() do
        assert_raise RuntimeError, ~r/Rust error/, fn ->
          Lux.Rust.eval!("undefined_var")
        end
      end
    end
  end
end
