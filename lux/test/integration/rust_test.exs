defmodule Lux.RustTest do
  @moduledoc """
  Integration tests for the native Rust core (`Lux.Rust`).

  These tests exercise the *compiled* NIF library end to end: they call the
  public `Lux.Rust` API, which is backed by the Rust `cdylib` built from
  `priv/rust`. Because they require the native library to be compiled, they are
  tagged `:integration` and excluded from the default test run (matching the
  repo's convention — see `IntegrationCase` in `test/test_helper.exs`).

  Run them with:

      mix rust.build
      mix test --include integration test/integration/rust_test.exs
  """

  use ExUnit.Case, async: true

  @moduletag :integration

  # `core_version/0` returns `{:ok, _}` only when the compiled NIF is loaded;
  # the pure-Elixir fallback stub returns `{:error, :nif_not_loaded}`. We assert
  # the native library is present up front so a missing build fails loudly with
  # a clear message rather than a confusing nif_error deep in a test.
  setup_all do
    case Lux.Rust.core_version() do
      {:ok, version} ->
        %{core_version: version}

      {:error, :nif_not_loaded} ->
        flunk("""
        The Lux Rust NIF is not loaded. Build the native core first:

            mix rust.build
        """)
    end
  end

  describe "native core" do
    test "reports the compiled core version" do
      assert {:ok, version} = Lux.Rust.core_version()
      assert is_binary(version)
      assert String.match?(version, ~r/^\d+\.\d+\.\d+/)
    end

    test "arithmetic NIFs cross the FFI boundary" do
      assert Lux.Rust.add(2, 3) == 5
      assert Lux.Rust.add(-1, 1) == 0
      assert Lux.Rust.multiply(4, 5) == 20
      assert Lux.Rust.multiply(0, 999) == 0
    end

    test "list NIFs round-trip through the BEAM" do
      assert Lux.Rust.sum_list([1, 2, 3, 4]) == 10
      assert Lux.Rust.sum_list([]) == 0
      assert Lux.Rust.reverse_list([1, 2, 3]) == [3, 2, 1]
    end

    test "binary checksum borrows the binary without copying" do
      assert Lux.Rust.binary_checksum(<<1, 2, 3>>) == 6
      assert Lux.Rust.binary_checksum(<<>>) == 0
      assert Lux.Rust.binary_checksum(<<255>>) == 255
    end

    test "string NIFs encode/decode UTF-8" do
      assert Lux.Rust.to_uppercase("hello") == "HELLO"
      assert Lux.Rust.join_strings(["a", "b", "c"], "-") == "a-b-c"
    end

    test "factorial returns {:ok, _} for valid input" do
      assert Lux.Rust.factorial(0) == {:ok, 1}
      assert Lux.Rust.factorial(5) == {:ok, 120}
      assert Lux.Rust.factorial(20) == {:ok, 2_432_902_008_176_640_000}
    end

    test "factorial returns a structured error for negative input" do
      assert {:error, error} = Lux.Rust.factorial(-1)
      assert error[:kind] == :invalid_argument
      assert is_binary(error[:message])
    end

    test "factorial returns a structured error on overflow" do
      assert {:error, error} = Lux.Rust.factorial(21)
      assert error[:kind] == :internal
    end

    test "parse_int decodes strings and reports errors" do
      assert Lux.Rust.parse_int("42") == {:ok, 42}
      assert Lux.Rust.parse_int("  7  ") == {:ok, 7}

      assert {:error, error} = Lux.Rust.parse_int("not a number")
      assert error[:kind] == :invalid_argument
    end

    test "map_get_int reads required integer keys" do
      assert Lux.Rust.map_get_int(%{"answer" => 42}, "answer") == {:ok, 42}

      assert {:error, error} = Lux.Rust.map_get_int(%{"answer" => "nope"}, "answer")
      assert error[:kind] == :invalid_argument

      assert {:error, _} = Lux.Rust.map_get_int(%{}, "missing")
    end

    test "safe_compute converts a Rust panic into an error tuple" do
      assert Lux.Rust.safe_compute(false) == {:ok, 99}

      assert {:error, error} = Lux.Rust.safe_compute(true)
      assert error[:kind] == :panic
    end
  end
end