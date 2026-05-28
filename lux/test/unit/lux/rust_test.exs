defmodule Lux.RustTest do
  use UnitCase, async: true

  alias Lux.Rust
  alias Lux.Rust.FFI

  @moduletag :unit

  # ── available?/0 ─────────────────────────────────────────────────────────────

  describe "available?/0" do
    test "returns a boolean" do
      assert is_boolean(Rust.available?())
    end
  end

  # ── version/0 ────────────────────────────────────────────────────────────────

  describe "version/0" do
    test "returns {:ok, string} or {:error, string}" do
      result = Rust.version()

      case result do
        {:ok, version} ->
          assert is_binary(version)

        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    @tag :skip_without_cargo
    test "version string starts with rustc when cargo is available" do
      if Rust.available?() do
        assert {:ok, version} = Rust.version()
        assert String.starts_with?(version, "rustc")
      end
    end
  end

  # ── eval/2 ───────────────────────────────────────────────────────────────────

  describe "eval/2" do
    @tag timeout: 60_000
    test "runs a hello-world program and returns stdout" do
      if Rust.available?() do
        code = ~s[fn main() { println!("Hello, World!"); }]
        assert {:ok, output} = Rust.eval(code)
        assert String.trim(output) == "Hello, World!"
      end
    end

    @tag timeout: 60_000
    test "returns {:error, stderr} for code that does not compile" do
      if Rust.available?() do
        code = ~s[fn main() { let _: i32 = "not an integer"; }]
        assert {:error, stderr} = Rust.eval(code)
        assert is_binary(stderr)
        assert byte_size(stderr) > 0
      end
    end

    test "returns {:error, _} when cargo is not available and skips if it is" do
      unless Rust.available?() do
        code = ~s[fn main() {}]
        result = Rust.eval(code)
        assert {:error, _} = result
      end
    end
  end

  # ── compile/2 ────────────────────────────────────────────────────────────────

  describe "compile/2" do
    @tag timeout: 60_000
    test "returns {:ok, binary_path} for valid code" do
      if Rust.available?() do
        code = ~s[fn main() {}]
        assert {:ok, path} = Rust.compile(code)
        assert is_binary(path)
      end
    end

    @tag timeout: 60_000
    test "returns {:error, _} for invalid code" do
      if Rust.available?() do
        code = "this is not rust"
        assert {:error, reason} = Rust.compile(code)
        assert is_binary(reason)
      end
    end
  end

  # ── with_deps/3 ──────────────────────────────────────────────────────────────

  describe "with_deps/3" do
    @tag timeout: 120_000
    test "runs code with no extra deps (same as eval)" do
      if Rust.available?() do
        code = ~s[fn main() { println!("deps ok"); }]
        assert {:ok, output} = Rust.with_deps(code, [], [])
        assert String.trim(output) == "deps ok"
      end
    end
  end

  # ── Lux.Rust.FFI.to_erlang_term/1 ────────────────────────────────────────────

  describe "FFI.to_erlang_term/1" do
    test "encodes nil" do
      assert {:ok, %{type: :nil, value: nil}} = FFI.to_erlang_term(nil)
    end

    test "encodes boolean true" do
      assert {:ok, %{type: :boolean, value: true}} = FFI.to_erlang_term(true)
    end

    test "encodes boolean false" do
      assert {:ok, %{type: :boolean, value: false}} = FFI.to_erlang_term(false)
    end

    test "encodes integer" do
      assert {:ok, %{type: :integer, value: 42}} = FFI.to_erlang_term(42)
    end

    test "encodes negative integer" do
      assert {:ok, %{type: :integer, value: -7}} = FFI.to_erlang_term(-7)
    end

    test "encodes float" do
      assert {:ok, %{type: :float, value: v}} = FFI.to_erlang_term(3.14)
      assert_in_delta v, 3.14, 0.0001
    end

    test "encodes binary string" do
      assert {:ok, %{type: :binary, value: "hello"}} = FFI.to_erlang_term("hello")
    end

    test "encodes atom" do
      assert {:ok, %{type: :atom, value: "ok"}} = FFI.to_erlang_term(:ok)
    end

    test "encodes list of integers" do
      assert {:ok, %{type: :list, value: items}} = FFI.to_erlang_term([1, 2, 3])
      assert length(items) == 3
      assert Enum.map(items, & &1.value) == [1, 2, 3]
    end

    test "encodes empty list" do
      assert {:ok, %{type: :list, value: []}} = FFI.to_erlang_term([])
    end

    test "encodes map" do
      assert {:ok, %{type: :map, value: pairs}} = FFI.to_erlang_term(%{"a" => 1})
      assert is_map(pairs)
    end

    test "returns error for unsupported type (tuple)" do
      assert {:error, reason} = FFI.to_erlang_term({:a, :b})
      assert is_binary(reason)
    end
  end

  # ── Lux.Rust.FFI.from_erlang_term/1 ──────────────────────────────────────────

  describe "FFI.from_erlang_term/1" do
    test "decodes nil" do
      assert {:ok, nil} = FFI.from_erlang_term(%{type: :nil, value: nil})
    end

    test "decodes boolean" do
      assert {:ok, true} = FFI.from_erlang_term(%{type: :boolean, value: true})
      assert {:ok, false} = FFI.from_erlang_term(%{type: :boolean, value: false})
    end

    test "decodes integer" do
      assert {:ok, 99} = FFI.from_erlang_term(%{type: :integer, value: 99})
    end

    test "decodes float" do
      assert {:ok, v} = FFI.from_erlang_term(%{type: :float, value: 2.5})
      assert_in_delta v, 2.5, 0.0001
    end

    test "decodes binary" do
      assert {:ok, "world"} = FFI.from_erlang_term(%{type: :binary, value: "world"})
    end

    test "decodes atom from string representation" do
      assert {:ok, :ok} = FFI.from_erlang_term(%{type: :atom, value: "ok"})
    end

    test "decodes list" do
      encoded = %{
        type: :list,
        value: [%{type: :integer, value: 10}, %{type: :integer, value: 20}]
      }

      assert {:ok, [10, 20]} = FFI.from_erlang_term(encoded)
    end

    test "returns error for unrecognised shape" do
      assert {:error, _} = FFI.from_erlang_term(%{not: :a_term})
    end
  end

  # ── Round-trip tests ─────────────────────────────────────────────────────────

  describe "FFI round-trip" do
    test "integer round-trips" do
      {:ok, encoded} = FFI.to_erlang_term(123)
      assert {:ok, 123} = FFI.from_erlang_term(encoded)
    end

    test "float round-trips" do
      {:ok, encoded} = FFI.to_erlang_term(1.5)
      assert {:ok, v} = FFI.from_erlang_term(encoded)
      assert_in_delta v, 1.5, 0.0001
    end

    test "boolean round-trips" do
      for b <- [true, false] do
        {:ok, encoded} = FFI.to_erlang_term(b)
        assert {:ok, ^b} = FFI.from_erlang_term(encoded)
      end
    end

    test "binary round-trips" do
      {:ok, encoded} = FFI.to_erlang_term("hello")
      assert {:ok, "hello"} = FFI.from_erlang_term(encoded)
    end

    test "nil round-trips" do
      {:ok, encoded} = FFI.to_erlang_term(nil)
      assert {:ok, nil} = FFI.from_erlang_term(encoded)
    end

    test "nested list round-trips" do
      {:ok, encoded} = FFI.to_erlang_term([1, 2, 3])
      assert {:ok, [1, 2, 3]} = FFI.from_erlang_term(encoded)
    end
  end

  # ── Lux.Rust.FFI.encode_for_nif/2 ────────────────────────────────────────────

  describe "FFI.encode_for_nif/2" do
    test "encodes u8 in range" do
      assert {:ok, %{type: :integer, value: 255}} = FFI.encode_for_nif(255, :u8)
    end

    test "rejects u8 out of range" do
      assert {:error, reason} = FFI.encode_for_nif(256, :u8)
      assert reason =~ "out of range"
    end

    test "encodes i32" do
      assert {:ok, %{type: :integer, value: -1}} = FFI.encode_for_nif(-1, :i32)
    end

    test "rejects negative for u32" do
      assert {:error, _} = FFI.encode_for_nif(-1, :u32)
    end

    test "encodes f64" do
      assert {:ok, %{type: :float, value: v}} = FFI.encode_for_nif(3.14, :f64)
      assert_in_delta v, 3.14, 0.0001
    end

    test "coerces integer to float" do
      assert {:ok, %{type: :float, value: 1.0}} = FFI.encode_for_nif(1, :f64)
    end

    test "encodes bool" do
      assert {:ok, %{type: :boolean, value: true}} = FFI.encode_for_nif(true, :bool)
    end

    test "rejects non-boolean for bool" do
      assert {:error, _} = FFI.encode_for_nif(1, :bool)
    end

    test "encodes string from binary" do
      assert {:ok, %{type: :binary, value: "hi"}} = FFI.encode_for_nif("hi", :string)
    end

    test "encodes string from atom" do
      assert {:ok, %{type: :binary, value: "ok"}} = FFI.encode_for_nif(:ok, :string)
    end

    test "returns error for wrong type" do
      assert {:error, _} = FFI.encode_for_nif("text", :u8)
    end
  end

  # ── Lux.Rust.FFI.decode_nif_result/1 ─────────────────────────────────────────

  describe "FFI.decode_nif_result/1" do
    test "decodes tagged integer" do
      assert {:ok, 7} = FFI.decode_nif_result(%{type: :integer, value: 7})
    end

    test "decodes tagged boolean" do
      assert {:ok, true} = FFI.decode_nif_result(%{type: :boolean, value: true})
    end

    test "passes through {:ok, value}" do
      assert {:ok, 42} = FFI.decode_nif_result({:ok, 42})
    end

    test "passes through {:error, binary}" do
      assert {:error, "boom"} = FFI.decode_nif_result({:error, "boom"})
    end

    test "decodes raw integer" do
      assert {:ok, 5} = FFI.decode_nif_result(5)
    end

    test "decodes raw binary" do
      assert {:ok, "hi"} = FFI.decode_nif_result("hi")
    end

    test "decodes raw boolean" do
      assert {:ok, false} = FFI.decode_nif_result(false)
    end

    test "decodes raw atom" do
      assert {:ok, :ok} = FFI.decode_nif_result(:ok)
    end

    test "decodes raw list" do
      assert {:ok, [1, 2]} = FFI.decode_nif_result([1, 2])
    end

    test "decodes raw map" do
      assert {:ok, %{"a" => 1}} = FFI.decode_nif_result(%{"a" => 1})
    end
  end
end
