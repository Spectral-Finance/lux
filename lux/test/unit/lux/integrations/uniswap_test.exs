defmodule Lux.Integrations.UniswapTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Uniswap

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "utility functions" do
    test "network/0 returns configured or default network" do
      assert Uniswap.network() in ["mainnet", "sepolia", "goerli", "arbitrum", "optimism", "polygon", "base"]
    end

    test "rpc_url/0 returns a valid url" do
      url = Uniswap.rpc_url()
      assert is_binary(url)
      assert String.starts_with?(url, "http")
    end

    test "validate_fee_tier/1 validates correct tiers" do
      assert {:ok, 3000} = Uniswap.validate_fee_tier(3000)
      assert {:error, _} = Uniswap.validate_fee_tier(4000)
    end

    test "validate_address/1 validates Ethereum addresses" do
      addr = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
      assert {:ok, ^addr} = Uniswap.validate_address(addr)
      assert {:error, _} = Uniswap.validate_address("0xinvalid")
    end

    test "sqrt_price_x96_to_price/3 computes correct price" do
      # For a 1:1 price ratio: sqrt(1) * 2^96 = 2^96
      sqrt_price_x96 = round(:math.pow(2, 96))
      assert_in_delta Uniswap.sqrt_price_x96_to_price(sqrt_price_x96, 18, 18), 1.0, 0.0001
    end

    test "tick_to_price/3 computes correct price" do
      # tick 0: 1.0001^0 = 1.0
      assert_in_delta Uniswap.tick_to_price(0, 18, 18), 1.0, 0.0001
    end

    test "price_to_tick/2 computes nearest tick" do
      # price 1.0 -> tick 0
      assert Uniswap.price_to_tick(1.0, 60) == 0
    end

    test "encode_function_selector/2 computes keccak signature selector" do
      # getPool(address,address,uint24) -> 0x1698ee82
      assert Uniswap.encode_function_selector("getPool", ["address", "address", "uint24"]) == "0x1698ee82"
    end

    test "decode_signed_int/2 handles positive and negative integers" do
      # positive: 0x000000000000000000000000000000000000000000000000000000000000002a -> 42
      hex_pos = String.pad_leading("2a", 64, "0")
      assert Uniswap.decode_signed_int("0x" <> hex_pos, 256) == 42

      # negative: 24-bit max negative
      # -12302 is 0xFFCFF2 which in uint256 is padded with Fs
      hex_neg = String.pad_leading("ffcff2", 64, "f")
      assert Uniswap.decode_signed_int("0x" <> hex_neg, 256) == -12302
    end
  end

  describe "on-chain call encoders" do
    test "encode_exact_input_single/1 encodes correctly" do
      params = %{
        token_in: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        token_out: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        fee: 3000,
        recipient: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        deadline: 1679529600,
        amount_in: 1000000,
        amount_out_minimum: 990000,
        sqrt_price_limit_x96: 0
      }
      calldata = Uniswap.encode_exact_input_single(params)
      assert is_binary(calldata)
      assert String.starts_with?(calldata, "0x")
      # exactInputSingle selector is 0x04e45584 or similar
      assert String.length(calldata) == 10 + 64 * 8
    end

    test "encode_mint/1 encodes correctly" do
      params = %{
        token0: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        token1: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        fee: 3000,
        tick_lower: -100,
        tick_upper: 100,
        amount0_desired: 10000,
        amount1_desired: 20000,
        amount0_min: 9000,
        amount1_min: 18000,
        recipient: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        deadline: 1679529600
      }
      calldata = Uniswap.encode_mint(params)
      assert is_binary(calldata)
      assert String.length(calldata) == 10 + 64 * 11
    end
  end

  describe "eth_call mocks" do
    test "get_pool/3 returns pool address" do
      token_a = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
      token_b = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
      expected_pool = "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640"

      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)
        assert payload["method"] == "eth_call"
        
        # Return pool address padded to 32 bytes
        result_payload = String.pad_leading(String.replace(expected_pool, "0x", ""), 64, "0")
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => "0x" <> result_payload}))
      end)

      assert {:ok, pool} = Uniswap.get_pool(token_a, token_b, 3000)
      assert String.downcase(pool) == expected_pool
    end

    test "get_pool_slot0/1 returns slot0 fields" do
      pool = "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640"
      
      Req.Test.expect(Lux.Lens, fn conn ->
        # slot0 returns 7 values:
        # sqrtPriceX96 (uint160), tick (int24), observationIndex (uint16), observationCardinality (uint16),
        # observationCardinalityNext (uint16), feeProtocol (uint8), unlocked (bool)
        
        val1 = String.pad_leading("ff001234", 64, "0") # sqrtPriceX96
        val2 = String.pad_leading("0", 64, "0") # tick
        val3 = String.pad_leading("5", 64, "0") # observationIndex
        val4 = String.pad_leading("10", 64, "0") # observationCardinality
        val5 = String.pad_leading("10", 64, "0") # observationCardinalityNext
        val6 = String.pad_leading("0", 64, "0") # feeProtocol
        val7 = String.pad_leading("1", 64, "0") # unlocked (true)
        
        result = "0x" <> val1 <> val2 <> val3 <> val4 <> val5 <> val6 <> val7

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => result}))
      end)

      assert {:ok, slot0} = Uniswap.get_pool_slot0(pool)
      assert slot0.sqrt_price_x96 == 4278194740
      assert slot0.tick == 0
      assert slot0.unlocked == true
    end

    test "get_liquidity_positions/1 returns list of positions" do
      owner = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

      # Expect 3 RPC calls:
      # 1. balanceOf(owner) -> returns 1
      # 2. tokenOfOwnerByIndex(owner, 0) -> returns tokenId (123)
      # 3. positions(123) -> returns position struct (12 values)
      
      Req.Test.expect(Lux.Lens, 3, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)
        [tx, _block] = payload["params"]
        data = tx["data"]

        cond do
          # balanceOf
          String.contains?(data, "70a08231") ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => "0x" <> String.pad_leading("1", 64, "0")}))

          # tokenOfOwnerByIndex
          String.contains?(data, "2f745c59") ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => "0x" <> String.pad_leading("7b", 64, "0")})) # 0x7b = 123

          # positions
          String.contains?(data, "99fbab88") ->
            # 12 fields
            fields = Enum.map(1..12, fn _ -> String.pad_leading("1", 64, "0") end) |> Enum.join("")
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => "0x" <> fields}))

          true ->
            conn
            |> Plug.Conn.send_resp(400, "Unexpected data: #{data}")
        end
      end)

      assert {:ok, [pos]} = Uniswap.get_liquidity_positions(owner)
      assert pos.token_id == 123
      assert pos.nonce == 1
      assert pos.liquidity == 1
    end
  end
end
