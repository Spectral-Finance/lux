defmodule Lux.Prisms.Ethereum.Gas.FeeOptimizerPrismTest do
  @moduledoc """
  Unit tests for FeeOptimizerPrism.

  All Ethereum JSON-RPC calls are intercepted via Req.Test so no real network
  traffic is produced during the test run.
  """

  use UnitCase, async: false

  alias Lux.Prisms.Ethereum.Gas.FeeOptimizerPrism

  @moduletag :unit

  @agent_ctx %{agent: %{name: "TestAgent"}}

  # eth_feeHistory mock response: 10 base fees + predicted next block fee.
  # Each fee is ~20 Gwei = 20_000_000_000 wei = 0x4A817C800
  @fee_history_response %{
    "baseFeePerGas" => [
      "0x4A817C800",
      "0x4B817C800",
      "0x4A817C800",
      "0x49817C800",
      "0x4A817C800",
      "0x4C817C800",
      "0x4A817C800",
      "0x4B817C800",
      "0x4A817C800",
      "0x4A817C800",
      # predicted next block
      "0x4A817C800"
    ],
    "oldestBlock" => "0x112A880",
    "gasUsedRatio" => [0.5, 0.6, 0.4, 0.55, 0.45, 0.65, 0.5, 0.5, 0.48, 0.52]
  }

  setup do
    Req.Test.verify_on_exit!()

    Application.put_env(:lux, FeeOptimizerPrism,
      plug: {Req.Test, FeeOptimizerPrismMock}
    )

    on_exit(fn ->
      Application.delete_env(:lux, FeeOptimizerPrism)
    end)

    :ok
  end

  describe "handler/2" do
    test "returns EIP-1559 fees for medium urgency" do
      Req.Test.expect(FeeOptimizerPrismMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["method"] == "eth_feeHistory"

        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @fee_history_response})
      end)

      assert {:ok, result} =
               FeeOptimizerPrism.handler(%{urgency: :medium, gas_limit: 21_000}, @agent_ctx)

      assert is_float(result.max_fee_per_gas)
      assert result.max_fee_per_gas > 0
      assert is_float(result.max_priority_fee)
      assert result.max_priority_fee > 0
      assert is_integer(result.estimated_wait_seconds)
      assert result.estimated_wait_seconds == 30
    end

    test "low urgency returns longest wait time" do
      Req.Test.expect(FeeOptimizerPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @fee_history_response})
      end)

      assert {:ok, result} = FeeOptimizerPrism.handler(%{urgency: :low}, @agent_ctx)
      assert result.estimated_wait_seconds == 120
      assert result.max_priority_fee == 0.5
    end

    test "urgent urgency returns shortest wait time" do
      Req.Test.expect(FeeOptimizerPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @fee_history_response})
      end)

      assert {:ok, result} = FeeOptimizerPrism.handler(%{urgency: :urgent}, @agent_ctx)
      assert result.estimated_wait_seconds == 6
      assert result.max_priority_fee == 4.0
    end

    test "high urgency returns 15-second wait" do
      Req.Test.expect(FeeOptimizerPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @fee_history_response})
      end)

      assert {:ok, result} = FeeOptimizerPrism.handler(%{urgency: :high}, @agent_ctx)
      assert result.estimated_wait_seconds == 15
      assert result.max_priority_fee == 2.5
    end

    test "accepts string urgency values" do
      Req.Test.expect(FeeOptimizerPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @fee_history_response})
      end)

      assert {:ok, result} = FeeOptimizerPrism.handler(%{urgency: "high"}, @agent_ctx)
      assert result.estimated_wait_seconds == 15
    end

    test "defaults to medium urgency when not specified" do
      Req.Test.expect(FeeOptimizerPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @fee_history_response})
      end)

      assert {:ok, result} = FeeOptimizerPrism.handler(%{}, @agent_ctx)
      assert result.estimated_wait_seconds == 30
    end

    test "max_fee_per_gas includes safety buffer above base fee" do
      Req.Test.expect(FeeOptimizerPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => @fee_history_response})
      end)

      assert {:ok, result} = FeeOptimizerPrism.handler(%{urgency: :medium}, @agent_ctx)

      # max_fee must be at least 2x base_fee + tip to handle fee spikes
      # base fee ≈ 20 Gwei, so max_fee should be > 40 + 1.5 = 41.5
      assert result.max_fee_per_gas >= result.max_priority_fee
      assert result.max_fee_per_gas > result.max_priority_fee
    end

    test "handles RPC error" do
      Req.Test.expect(FeeOptimizerPrismMock, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "error" => %{"code" => -32601, "message" => "Method not supported"}
        })
      end)

      assert {:error, reason} = FeeOptimizerPrism.handler(%{urgency: :medium}, @agent_ctx)
      assert String.contains?(reason, "eth_feeHistory RPC error")
    end

    test "handles empty fee history" do
      empty_history = %{
        "baseFeePerGas" => [],
        "oldestBlock" => "0x0",
        "gasUsedRatio" => []
      }

      Req.Test.expect(FeeOptimizerPrismMock, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => empty_history})
      end)

      assert {:error, reason} = FeeOptimizerPrism.handler(%{urgency: :medium}, @agent_ctx)
      assert String.contains?(reason, "No base fee history")
    end
  end

  describe "schema validation" do
    test "urgency enum contains all four levels" do
      prism = FeeOptimizerPrism.view()
      urgency_prop = prism.input_schema.properties.urgency
      assert "low" in urgency_prop.enum
      assert "medium" in urgency_prop.enum
      assert "high" in urgency_prop.enum
      assert "urgent" in urgency_prop.enum
    end

    test "output schema requires all three fee fields" do
      prism = FeeOptimizerPrism.view()
      required = prism.output_schema.required
      assert "max_fee_per_gas" in required
      assert "max_priority_fee" in required
      assert "estimated_wait_seconds" in required
    end

    test "no required input fields" do
      prism = FeeOptimizerPrism.view()
      assert prism.input_schema.required == []
    end
  end
end
