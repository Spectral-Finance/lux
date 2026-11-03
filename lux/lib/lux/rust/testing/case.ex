defmodule Lux.Rust.Testing.Case do
  @moduledoc """
  ExUnit test case template and assertion helpers for testing native Rust integration.

  ## Usage

      defmodule MyRustTest do
        use Lux.Rust.Testing.Case

        test "executes fibonacci" do
          assert_rust_call("math.fibonacci", %{"n" => 10}, 55)
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case, async: true

      import Lux.Rust.Testing.Case
      alias Lux.Rust
      alias Lux.Rust.Error, as: RustError
    end
  end

  defmacro assert_rust_call(func, args, expected) do
    quote do
      case Lux.Rust.call(unquote(func), unquote(args)) do
        {:ok, result} ->
          assert result == unquote(expected)

        {:error, err} ->
          flunk("Rust call '#{unquote(func)}' failed with error: #{inspect(err)}")
      end
    end
  end

  defmacro assert_rust_error(func, args, expected_type) do
    quote do
      case Lux.Rust.call(unquote(func), unquote(args)) do
        {:error, %Lux.Rust.Error{type: type}} ->
          assert type == unquote(expected_type)

        {:ok, result} ->
          flunk("Expected error #{unquote(expected_type)}, but call succeeded with #{inspect(result)}")
      end
    end
  end
end
