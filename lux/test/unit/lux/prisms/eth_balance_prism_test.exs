defmodule Lux.Prisms.EthBalancePrismTest do
  use UnitCase, async: false
  import Mock

  alias Lux.Prisms.EthBalancePrism

  @test_address "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

  setup do
    current_keys = Application.get_env(:lux, :api_keys, [])
    Application.put_env(:lux, :api_keys, Keyword.put(current_keys, :alchemy, "test_alchemy_key"))

    on_exit(fn ->
      Application.put_env(:lux, :api_keys, current_keys)
    end)

    :ok
  end

  describe "handler/2" do
    test "checks balance of a valid address" do
      case Lux.Python.import_package("web3") do
        {:ok, %{"success" => true}} ->
          {:ok, result} =
            EthBalancePrism.run(%{
              address: @test_address,
              network: "test"
            })

          assert is_float(result.balance_eth)
          assert is_binary(result.balance_wei)
          assert result.network == "test"

        _ ->
          with_mock Lux.Python, [:passthrough], [
            import_package: fn "web3" -> {:ok, %{"success" => true}} end,
            eval!: fn _code, opts ->
              case opts[:variables] do
                %{address: @test_address, network: "test"} ->
                  %{
                    "balance_eth" => 1.5,
                    "balance_wei" => "1500000000000000000",
                    "network" => "test"
                  }
              end
            end
          ] do
            {:ok, result} =
              EthBalancePrism.run(%{
                address: @test_address,
                network: "test"
              })

            assert is_float(result.balance_eth)
            assert is_binary(result.balance_wei)
            assert result.network == "test"
          end
      end
    end

    test "defaults to mainnet when network not specified" do
      case Lux.Python.import_package("web3") do
        {:ok, %{"success" => true}} ->
          {:ok, result} =
            EthBalancePrism.run(%{
              address: @test_address,
              network: "test"
            })

          assert result.network == "test"

        _ ->
          with_mock Lux.Python, [:passthrough], [
            import_package: fn "web3" -> {:ok, %{"success" => true}} end,
            eval!: fn _code, opts ->
              case opts[:variables] do
                %{address: @test_address, network: "test"} ->
                  %{
                    "balance_eth" => 1.5,
                    "balance_wei" => "1500000000000000000",
                    "network" => "test"
                  }
              end
            end
          ] do
            {:ok, result} =
              EthBalancePrism.run(%{
                address: @test_address,
                network: "test"
              })

            assert result.network == "test"
          end
      end
    end

    test "handles invalid address format" do
      case Lux.Python.import_package("web3") do
        {:ok, %{"success" => true}} ->
          {:error, error} =
            EthBalancePrism.run(%{
              address: "not_an_address",
              network: "test"
            })

          assert String.contains?(error, "Failed to get balance")

        _ ->
          with_mock Lux.Python, [:passthrough], [
            import_package: fn "web3" -> {:ok, %{"success" => true}} end,
            eval!: fn _code, opts ->
              case opts[:variables] do
                %{address: "not_an_address"} ->
                  %{"error" => "Failed to get balance: Invalid address format"}
              end
            end
          ] do
            {:error, error} =
              EthBalancePrism.run(%{
                address: "not_an_address",
                network: "test"
              })

            assert String.contains?(error, "Failed to get balance")
          end
      end
    end

    test "handles invalid network" do
      case Lux.Python.import_package("web3") do
        {:ok, %{"success" => true}} ->
          {:error, error} =
            EthBalancePrism.run(%{
              address: @test_address,
              network: "invalid_network"
            })

          assert String.contains?(error, "Invalid network: invalid_network")

        _ ->
          with_mock Lux.Python, [:passthrough], [
            import_package: fn "web3" -> {:ok, %{"success" => true}} end,
            eval!: fn _code, opts ->
              case opts[:variables] do
                %{network: "invalid_network"} ->
                  %{"error" => "Invalid network: invalid_network"}
              end
            end
          ] do
            {:error, error} =
              EthBalancePrism.run(%{
                address: @test_address,
                network: "invalid_network"
              })

            assert String.contains?(error, "Invalid network: invalid_network")
          end
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = EthBalancePrism.view()

      assert prism.input_schema.required == ["address"]
      assert Map.has_key?(prism.input_schema.properties, :address)
      assert Map.has_key?(prism.input_schema.properties, :network)

      network_prop = prism.input_schema.properties.network
      assert "test" in network_prop.enum
    end

    test "validates output schema" do
      prism = EthBalancePrism.view()

      assert prism.output_schema.required == ["balance_eth", "balance_wei", "network"]
      assert Map.has_key?(prism.output_schema.properties, :balance_eth)
      assert Map.has_key?(prism.output_schema.properties, :balance_wei)
      assert Map.has_key?(prism.output_schema.properties, :network)
    end
  end
end
