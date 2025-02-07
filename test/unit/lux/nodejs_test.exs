defmodule Lux.NodeJSTest do
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

      assert {:error, "Call timed out."} = result
    end
  end

  describe "web3 integration" do
    test "loads and uses web3 library" do
      assert {:ok, %{"success" => true}} = import_package("web3")

      result =
        nodejs variables: %{address: "0xd3cda913deb6f67967b99d67acdfa1712c293601"} do
          ~JS"""
          import {validator} from 'web3'

          export const main = ({address}) => {
            return {
              address,
              valid: validator.isAddress(address, true)
            };
          }
          """
        end

      assert {:ok, %{"address" => _, "valid" => true}} = result
    end
  end
end
