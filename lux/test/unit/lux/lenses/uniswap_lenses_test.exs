defmodule Lux.Lenses.UniswapLensesTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Uniswap.GetPoolInfo
  alias Lux.Lenses.Uniswap.GetLiquidityPositions
  alias Lux.Lenses.Uniswap.GetTokenPrices
  alias Lux.Lenses.Uniswap.GetSwapQuote

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "GetPoolInfo lens" do
    test "successfully fetches pool info with direct pool address" do
      pool = "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640"

      Req.Test.expect(Lux.Lens, 2, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)
        [tx, _] = payload["params"]
        data = tx["data"]

        cond do
          # slot0
          String.contains?(data, "3850c7bd") ->
            val1 = String.pad_leading("ff001234", 64, "0") # sqrtPriceX96
            val2 = String.pad_leading("0", 64, "0") # tick
            rest = Enum.map(3..7, fn _ -> String.pad_leading("0", 64, "0") end) |> Enum.join("")
            
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => "0x" <> val1 <> val2 <> rest}))

          # liquidity
          String.contains?(data, "1a686502") ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => "0x" <> String.pad_leading("de0b6b3a7640000", 64, "0")})) # 10^18

          true ->
            IO.inspect(data, label: "UNEXPECTED DATA")
            conn |> Plug.Conn.send_resp(400, "Unexpected")
        end
      end)

      assert {:ok, result} = GetPoolInfo.focus(%{pool_address: pool, network: "mainnet"}, %{})
      assert result.pool_address == pool
      assert result.sqrt_price_x96 == 4278194740
      assert result.tick == 0
      assert result.liquidity == 1000000000000000000
    end
  end

  describe "GetLiquidityPositions lens" do
    test "focuses and returns list of positions" do
      owner = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

      Req.Test.expect(Lux.Lens, 3, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)
        [tx, _] = payload["params"]
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
            |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => "0x" <> String.pad_leading("7b", 64, "0")})) # 123

          # positions
          String.contains?(data, "99fbab88") ->
            fields = Enum.map(1..12, fn _ -> String.pad_leading("1", 64, "0") end) |> Enum.join("")
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => "0x" <> fields}))

          true ->
            conn |> Plug.Conn.send_resp(400, "Unexpected")
        end
      end)

      assert {:ok, result} = GetLiquidityPositions.focus(%{owner: owner, network: "mainnet"}, %{})
      assert is_list(result.positions)
      assert length(result.positions) == 1
      assert hd(result.positions).token_id == 123
    end
  end

  describe "GetTokenPrices lens" do
    test "focuses and returns relative prices" do
      pool = "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640"

      Req.Test.expect(Lux.Lens, fn conn ->
        val1 = String.pad_leading("ff001234", 64, "0") # sqrtPriceX96
        val2 = String.pad_leading("0", 64, "0") # tick
        rest = Enum.map(3..7, fn _ -> String.pad_leading("0", 64, "0") end) |> Enum.join("")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => "0x" <> val1 <> val2 <> rest}))
      end)

      assert {:ok, result} = GetTokenPrices.focus(%{pool_address: pool, network: "mainnet"}, %{})
      assert result.pool_address == pool
      assert result.price_0_in_1 > 0
      assert result.price_1_in_0 > 0
    end
  end

  describe "GetSwapQuote lens" do
    test "focuses and returns swap quote" do
      token_in = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
      token_out = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

      Req.Test.expect(Lux.Lens, fn conn ->
        # quoteExactInputSingle selector is 0xf7729d43 or similar
        # returns uint256 amountOut
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => "0x" <> String.pad_leading("f4240", 64, "0")})) # 1000000
      end)

      assert {:ok, result} = GetSwapQuote.focus(%{
        token_in: token_in,
        token_out: token_out,
        fee: 3000,
        amount_in: 1000000,
        network: "mainnet"
      }, %{})
      assert result.amount_out == 1000000
    end
  end
end
