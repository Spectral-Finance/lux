defmodule Lux.Web3.GasTest do
  use UnitAPICase, async: true

  alias Lux.Web3.Gas

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "hex_to_int/1" do
    test "parses 0x-prefixed hex string" do
      assert {:ok, 21000} = Gas.hex_to_int("0x5208")
    end

    test "parses 0X-prefixed hex string" do
      assert {:ok, 255} = Gas.hex_to_int("0XFF")
    end

    test "parses lowercase hex digits" do
      assert {:ok, 4_294_967_295} = Gas.hex_to_int("0xffffffff")
    end

    test "parses mixed-case hex digits" do
      assert {:ok, 4_398_066_111} = Gas.hex_to_int("0xDeAdBeEf")
    end

    test "parses plain decimal string (backward compatibility)" do
      assert {:ok, 21000} = Gas.hex_to_int("21000")
    end

    test "parses zero" do
      assert {:ok, 0} = Gas.hex_to_int("0x0")
      assert {:ok, 0} = Gas.hex_to_int("0x00")
    end

    test "returns error for invalid hex string" do
      assert {:error, _} = Gas.hex_to_int("0xzzzz")
    end

    test "returns error for non-string input" do
      assert {:error, _} = Gas.hex_to_int(123)
      assert {:error, _} = Gas.hex_to_int(nil)
    end

    test "parses large gas price values" do
      # Typical gas price ~20 gwei = 20_000_000_000 wei = 0x4a817c800
      assert {:ok, 20_000_000_000} = Gas.hex_to_int("0x4a817c800")
    end

    test "parses Ethereum block gas limit" do
      # 30_000_000 gas
      assert {:ok, 30_000_000} = Gas.hex_to_int("0x1c9c380")
    end
  end

  describe "estimate_gas/3" do
    test "parses hex result from eth_estimateGas into integer" do
      Req.Test.expect(fn conn ->
        body = Jason.decode!(conn.body_params)

        assert body["method"] == "eth_estimateGas"
        assert body["params"] == [%{"to" => "0xabc", "data" => "0x1234"}, "latest"]

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{jsonrpc: "2.0", id: 1, result: "0x5208"}))
      end)

      assert {:ok, %{gas: 21000, chain: :ethereum}} = Gas.estimate_gas("0xabc", "0x1234")
    end

    test "propagates JSON-RPC error" do
      Req.Test.expect(fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{jsonrpc: "2.0", id: 1, error: %{code: -32000, message: "gas estimation failed"}})
        )
      end)

      assert {:error, %{"code" => -32000}} = Gas.estimate_gas("0xabc", "0x1234")
    end

    test "returns error for invalid hex result" do
      Req.Test.expect(fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{jsonrpc: "2.0", id: 1, result: "0xinvalid"}))
      end)

      assert {:error, _} = Gas.estimate_gas("0xabc", "0x1234")
    end
  end

  describe "gas_price/2" do
    test "parses hex result from eth_gasPrice and computes gwei" do
      Req.Test.expect(fn conn ->
        body = Jason.decode!(conn.body_params)

        assert body["method"] == "eth_gasPrice"
        assert body["params"] == []

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{jsonrpc: "2.0", id: 1, result: "0x4a817c800"}))
      end)

      assert {:ok, %{wei: 20_000_000_000, gwei: gwei, chain: :ethereum}} = Gas.gas_price()
      assert_in_delta gwei, 20.0, 0.001
    end

    test "propagates JSON-RPC error" do
      Req.Test.expect(fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{jsonrpc: "2.0", id: 1, error: %{code: -32000, message: "gas price not available"}})
        )
      end)

      assert {:error, _} = Gas.gas_price()
    end

    test "returns error for invalid hex result" do
      Req.Test.expect(fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{jsonrpc: "2.0", id: 1, result: "0xINVALID"}))
      end)

      assert {:error, _} = Gas.gas_price()
    end
  end

  describe "gas_price_hex/1" do
    test "returns raw hex string from eth_gasPrice" do
      Req.Test.expect(fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{jsonrpc: "2.0", id: 1, result: "0x4a817c800"}))
      end)

      assert {:ok, %{hex: "0x4a817c800", chain: :ethereum}} = Gas.gas_price_hex()
    end

    test "propagates JSON-RPC error" do
      Req.Test.expect(fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{jsonrpc: "2.0", id: 1, error: %{code: -32000, message: "not available"}})
        )
      end)

      assert {:error, _} = Gas.gas_price_hex()
    end
  end

  describe "optimize_gas/4" do
    test "returns feasible when estimated gas is within max_gas" do
      Req.Test.expect(fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{jsonrpc: "2.0", id: 1, result: "0x5208"}))
      end)

      Req.Test.expect(fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{jsonrpc: "2.0", id: 1, result: "0x4a817c800"}))
      end)

      assert {:ok, result} = Gas.optimize_gas("0xabc", "0x1234", 50_000)
      assert result.estimated == 21_000
      assert result.feasible == true
      assert_in_delta result.price_gwei, 20.0, 0.001
      assert_in_delta result.total_eth, 21_000 * 20.0 / 1_000_000_000, 0.0001
    end

    test "returns not feasible when estimated gas exceeds max_gas with overshoot" do
      Req.Test.expect(fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{jsonrpc: "2.0", id: 1, result: "0x5208"}))
      end)

      Req.Test.expect(fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{jsonrpc: "2.0", id: 1, result: "0x4a817c800"}))
      end)

      assert {:ok, result} = Gas.optimize_gas("0xabc", "0x1234", 10_000)
      assert result.estimated == 21_000
      assert result.feasible == false
      assert result.overshoot == 11_000
    end

    test "propagates error from estimate_gas" do
      Req.Test.expect(fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{jsonrpc: "2.0", id: 1, error: %{code: -32000, message: "execution reverted"}})
        )
      end)

      assert {:error, _} = Gas.optimize_gas("0xabc", "0x1234", 50_000)
    end
  end
end
