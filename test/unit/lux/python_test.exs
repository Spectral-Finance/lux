defmodule Lux.PythonTest do
  use UnitCase, async: true

  import Lux.Python

  require Lux.Python

  describe "eval/2" do
    test "evaluates simple Python expressions" do
      assert {:ok, 2} = Lux.Python.eval("1 + 1")
    end

    test "evaluates code with variable bindings" do
      assert {:ok, 30} = Lux.Python.eval("x * y", variables: %{x: 5, y: 6})
    end

    test "supports multi-line code" do
      code = """
      def factorial(n):
          if n <= 1:
              return 1
          return n * factorial(n - 1)
      factorial(n)
      """

      assert {:ok, 120} = Lux.Python.eval(code, variables: %{n: 5})
    end
  end

  describe "eval!/2" do
    test "returns result directly on success" do
      assert 3 == Lux.Python.eval!("1 + 2")
    end

    test "raises error on failure" do
      assert_raise RuntimeError,
                   ~r/Python error: NameError: name 'undefined_var' is not defined/,
                   fn ->
                     Lux.Python.eval!("undefined_var")
                   end
    end

    test "supports variable bindings" do
      assert 42 == Lux.Python.eval!("x * 2", variables: %{x: 21})
    end
  end

  describe "python/2 macro" do
    test "executes simple Python expressions" do
      result =
        python do
          ~PY"""
          2 + 2
          """
        end

      assert result == 4
    end

    test "supports variable bindings" do
      result =
        python variables: %{x: 10, y: 20} do
          ~PY"""
          x * y
          """
        end

      assert result == 200
    end

    test "handles multi-line Python code" do
      result =
        python do
          ~PY"""
          def factorial(n):
              if n <= 1:
                  return 1
              return n * factorial(n - 1)
          factorial(5)
          """
        end

      assert result == 120
    end

    test "supports list operations with variables" do
      result =
        python variables: %{data: [1, 2, 3, 4, 5]} do
          ~PY"""
          sum(x * 2 for x in data)
          """
        end

      assert result == 30
    end

    test "raises error for invalid Python code" do
      assert_raise RuntimeError,
                   ~r/Python error: NameError: name 'undefined_variable' is not defined/,
                   fn ->
                     python do
                       ~PY"""
                       undefined_variable
                       """
                     end
                   end
    end

    test "handles string interpolation in Python" do
      result =
        python variables: %{name: "World"} do
          ~PY"""
          f"Hello, {name}!"
          """
        end

      assert result == "Hello, World!"
    end

    test "respects timeout option" do
      assert_raise RuntimeError, ~r/timeout/, fn ->
        python timeout: 1 do
          ~PY"""
          import time
          time.sleep(2)
          """
        end
      end
    end

    test "supports multiple options simultaneously" do
      result =
        python timeout: 1000,
               variables: %{x: 10} do
          ~PY"""
          x * 2
          """
        end

      assert result == 20
    end
  end

  describe "web3 integration" do
    test "loads and uses web3 libraries" do
      # Import required packages
      assert {:ok, %{"success" => true}} = Lux.Python.import_package("web3")
      assert {:ok, %{"success" => true}} = Lux.Python.import_package("eth_utils")

      # Test creating a Web3 instance and using eth_utils
      result =
        python do
          ~PY"""
          from web3 import Web3
          from eth_utils import to_checksum_address, is_address

          # Test eth_utils functions
          address = "0xd3cda913deb6f67967b99d67acdfa1712c293601"
          checksum = to_checksum_address(address)
          is_valid = is_address(checksum)

          {"address": checksum, "is_valid": is_valid}
          """
        end

      assert %{
               "address" => "0xd3CdA913deB6f67967B99D67aCDFa1712C293601",
               "is_valid" => true
             } = result

      # Test Web3 instance creation and basic functionality
      result =
        python do
          ~PY"""
          from web3 import Web3

          # Create a Web3 instance using local provider (won't actually connect)
          w3 = Web3(Web3.EthereumTesterProvider())

          # Test some basic Web3 functionality
          account = w3.eth.account.create()
          address = account.address

          # Return some basic info
          {
              "connected": w3.is_connected(),
              "address_valid": Web3.is_address(address),
              "checksum_address": Web3.to_checksum_address(address.lower())
          }
          """
        end

      assert %{
               "connected" => true,
               "address_valid" => true,
               "checksum_address" => checksum_addr
             } = result

      assert String.starts_with?(checksum_addr, "0x")
    end
  end
end
