defmodule Lux.NodeJSTest do
  @moduledoc """
  Comprehensive tests for Lux.NodeJS module.

  Tests cover:
  - Code evaluation (eval/2, eval!/2)
  - Variable bindings
  - Error handling (timeout, invalid code, runtime errors)
  - Package import functionality
  - The nodejs macro
  - Edge cases and regression tests
  """
  use UnitCase, async: true

  import Lux.NodeJS

  require Lux.NodeJS

  describe "eval/2" do
    test "evaluates simple Node.js expressions" do
      assert {:ok, 2} = eval("export const main = () => 1 + 1")
    end

    test "evaluates code with variable bindings" do
      assert {:ok, 30} =
               eval("export const main = ({x, y}) => x * y", variables: %{x: 5, y: 6})
    end

    test "supports multi-line code" do
      code = """
      export const main = ({n}) => {
          const factorial = (n) => {
              if (n <= 1) {
                  return 1
              }
              return n * factorial(n - 1)
          }
          return factorial(n)
      }
      """

      assert {:ok, 120} = eval(code, variables: %{n: 5})
    end

    test "handles string return values" do
      assert {:ok, "hello world"} =
               eval("export const main = () => 'hello world'")
    end

    test "handles object return values" do
      assert {:ok, %{"a" => 1, "b" => 2}} =
               eval("export const main = () => ({a: 1, b: 2})")
    end

    test "handles array return values" do
      assert {:ok, [1, 2, 3]} = eval("export const main = () => [1, 2, 3]")
    end

    test "handles boolean return values" do
      assert {:ok, true} = eval("export const main = () => true")
      assert {:ok, false} = eval("export const main = () => false")
    end

    test "handles null return values" do
      assert {:ok, nil} = eval("export const main = () => null")
    end

    test "handles async functions" do
      code = """
      export const main = async () => {
        await new Promise(resolve => setTimeout(resolve, 10))
        return 42
      }
      """

      assert {:ok, 42} = eval(code)
    end

    test "returns error for empty code" do
      assert {:error, :invalid_code} = eval("")
      assert {:error, :invalid_code} = eval("   ")
    end

    test "returns error for runtime errors" do
      assert {:error, _} = eval("export const main = () => undefined_var")
    end

    test "supports complex variable types" do
      assert {:ok, %{"result" => [1, 2, 3]}} =
               eval(
                 "export const main = ({data}) => ({result: data.flat()})",
                 variables: %{data: [1, [2, [3]]]}
               )
    end
  end

  describe "eval!/2" do
    test "returns result directly on success" do
      assert 3 == eval!("export const main = () => 1 + 2")
    end

    test "raises error on failure" do
      assert_raise NodeJS.Error,
                   ~r/undefined_var is not defined/,
                   fn ->
                     eval!("undefined_var")
                   end
    end

    test "raises error for empty code" do
      assert_raise FunctionClauseError, fn ->
        eval!("")
      end
    end

    test "supports variable bindings" do
      assert 42 == eval!("export const main = ({x}) => x * 2", variables: %{x: 21})
    end
  end

  describe "node/2 macro" do
    test "executes simple Node.js expressions" do
      result =
        nodejs do
          ~JS"""
          export const main = () => 2 + 2
          """
        end

      assert {:ok, 4} = result
    end

    test "supports variable bindings" do
      result =
        nodejs variables: %{x: 21} do
          ~JS"""
          export const main = ({x}) => x * 2
          """
        end

      assert {:ok, 42} = result
    end

    test "handle multi-line Node.js code" do
      result =
        nodejs do
          ~JS"""
          export const main = () => {
              const factorial = (n) => {
                  if (n <= 1) {
                      return 1
                  }
                  return n * factorial(n - 1)
              }
              return factorial(5)
          }
          """
        end

      assert {:ok, 120} = result
    end

    test "respects timeout option" do
      result =
        nodejs timeout: 10 do
          ~JS"""
          export const main = async () => {
             await new Promise(resolve => setTimeout(() => resolve(), 1000))
          }
          """
        end

      assert {:error, :timeout} = result
    end

    test "keeps working after timeout" do
      timeout_result =
        nodejs timeout: 10 do
          ~JS"""
          export const main = async () => {
             await new Promise(resolve => setTimeout(() => resolve(), 1000))
          }
          """
        end

      assert {:error, :timeout} = timeout_result
      assert {:ok, 4} = eval("export const main = () => 2 + 2")
    end
  end

  describe "web3 integration" do
    @tag :skip
    test "loads and uses web3 library" do
      assert {:ok, %{"success" => true}} = import_package("flatten", update_lock_file: false)

      result =
        nodejs variables: %{data: [1, [2, [3]]]} do
          ~JS"""
          import flatten from 'flatten'

          export const main = ({data}) => {
            return {
              result: flatten(data),
            };
          }
          """
        end

      assert {:ok, %{"result" => [1, 2, 3]}} = result
    end
  end
end
