defmodule Lux.Prisms.Ethereum.Gas.GasEstimatorPrismTest do
  @moduledoc """
  Unit tests for GasEstimatorPrism.

  All Ethereum JSON-RPC calls are intercepted via Req.Test so no real network
  traffic is produced during the test run.
  """

  use UnitCase, async: false

  alias Lux.Prisms.Ethereum.Gas.GasEstimatorPrism

  @moduletag :unit

  @from "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  @to "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  # Hex-encoded gas values used in mock responses.
  # 21000 in hex = 0x5208
  @gas_hex "0x5208"
  # 20 Gwei in wei = 20_000_000_000 = 0x4A817C800
  @gas_price_hex "0x4A817C800"

  setup do
    Req.Test.verify_on_exit!()

    Application.put_env(:lux, GasEstimatorPrism,
      plug: {Req.Test, GasEstimatorPrismMock}
    )

    on_exit(fn ->
      Application.delete_env(:lux, GasEstimatorPrism)
    end)

    :ok
  end

  describe "handler/2" do
    test "estimates gas cost for a simple ETH transfer" do
      # eth_estimateGas call
      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["method"] == "eth_estimateGas"

        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @gas_hex})
      end)

      # eth_gasPrice call
      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["method"] == "eth_gasPrice"

        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 2, "result" => @gas_price_hex})
      end)

      assert {:ok, result} =
               GasEstimatorPrism.handler(
                 %{from: @from, to: @to, value_eth: 0.1, priority: :standard},
                 @agent_ctx
               )

      assert result.estimated_gas == 21_000
      assert is_float(result.gas_price_gwei)
      assert result.gas_price_gwei > 0
      assert is_float(result.total_cost_eth)
      assert result.total_cost_eth > 0
      assert is_float(result.total_cost_usd)
      assert result.total_cost_usd > 0
    end

    test "applies low priority gas price multiplier" do
      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @gas_hex})
      end)

      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 2, "result" => @gas_price_hex})
      end)

      assert {:ok, low_result} =
               GasEstimatorPrism.handler(
                 %{from: @from, to: @to, value_eth: 0.0, priority: :low},
                 @agent_ctx
               )

      # Low priority should use 85% of base gas price
      assert low_result.gas_price_gwei > 0
    end

    test "applies urgent priority gas price multiplier" do
      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @gas_hex})
      end)

      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 2, "result" => @gas_price_hex})
      end)

      assert {:ok, urgent_result} =
               GasEstimatorPrism.handler(
                 %{from: @from, to: @to, value_eth: 0.0, priority: :urgent},
                 @agent_ctx
               )

      # Urgent priority should use 150% of base gas price
      assert urgent_result.gas_price_gwei > 0
    end

    test "accepts string priority values" do
      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @gas_hex})
      end)

      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 2, "result" => @gas_price_hex})
      end)

      assert {:ok, result} =
               GasEstimatorPrism.handler(
                 %{from: @from, to: @to, priority: "fast"},
                 @agent_ctx
               )

      assert result.estimated_gas == 21_000
    end

    test "handles RPC error from eth_estimateGas" do
      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "error" => %{"code" => -32000, "message" => "execution reverted"}
        })
      end)

      assert {:error, reason} =
               GasEstimatorPrism.handler(
                 %{from: @from, to: @to, value_eth: 0.0},
                 @agent_ctx
               )

      assert String.contains?(reason, "eth_estimateGas error")
    end

    test "handles optional data parameter" do
      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        # data should be present in the tx object when provided
        tx_object = hd(decoded["params"])
        assert Map.has_key?(tx_object, "data")

        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @gas_hex})
      end)

      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 2, "result" => @gas_price_hex})
      end)

      assert {:ok, result} =
               GasEstimatorPrism.handler(
                 %{from: @from, to: @to, data: "0xa9059cbb0000"},
                 @agent_ctx
               )

      assert result.estimated_gas == 21_000
    end

    test "defaults to zero value when value_eth is omitted" do
      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        tx_object = hd(decoded["params"])
        assert tx_object["value"] == "0x0"

        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @gas_hex})
      end)

      Req.Test.expect(GasEstimatorPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 2, "result" => @gas_price_hex})
      end)

      assert {:ok, result} = GasEstimatorPrism.handler(%{from: @from, to: @to}, @agent_ctx)
      assert result.estimated_gas == 21_000
    end
  end

  describe "schema validation" do
    test "input schema requires from and to" do
      prism = GasEstimatorPrism.view()
      assert "from" in prism.input_schema.required
      assert "to" in prism.input_schema.required
    end

    test "output schema requires all cost fields" do
      prism = GasEstimatorPrism.view()
      required = prism.output_schema.required
      assert "estimated_gas" in required
      assert "gas_price_gwei" in required
      assert "total_cost_eth" in required
      assert "total_cost_usd" in required
    end

    test "input schema has priority enum" do
      prism = GasEstimatorPrism.view()
      priority_prop = prism.input_schema.properties.priority
      assert "low" in priority_prop.enum
      assert "standard" in priority_prop.enum
      assert "fast" in priority_prop.enum
      assert "urgent" in priority_prop.enum
    end
  end
end
