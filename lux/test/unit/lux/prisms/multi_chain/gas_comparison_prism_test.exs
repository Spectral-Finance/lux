defmodule Lux.Prisms.MultiChain.GasComparisonPrismTest do
  use UnitAPICase, async: false

  alias Lux.MultiChain.Cache
  alias Lux.Prisms.MultiChain.GasComparisonPrism

  setup do
    Cache.init()
    Cache.clear_all()

    Application.put_env(:lux, :multi_chain, %{
      rpc_endpoints: %{
        ethereum: ["http://localhost:8545"],
        polygon: ["http://localhost:8546"]
      }
    })

    Req.Test.verify_on_exit!()
    :ok
  end

  describe "view/0" do
    test "returns the prism configuration" do
      prism = GasComparisonPrism.view()
      assert prism.name == "Gas Price Comparison"
    end
  end

  describe "handler/2" do
    test "compares gas prices across chains" do
      for _i <- 1..2 do
        Req.Test.expect(Lux.Lens, fn conn ->
          Req.Test.json(conn, %{
            "jsonrpc" => "2.0",
            "id" => 1,
            "result" => "0x4A817C800"
          })
        end)
      end

      assert {:ok, result} =
               GasComparisonPrism.handler(
                 %{chains: ["ethereum", "polygon"]},
                 nil
               )

      assert length(result.gas_prices) == 2
      assert result.cheapest_chain != nil
      assert result.most_expensive_chain != nil

      for price <- result.gas_prices do
        assert price.standard_gwei > 0
        assert price.fast_gwei > 0
        assert price.chain in ["ethereum", "polygon"]
      end
    end

    test "sorts results by standard gas price ascending" do
      # Ethereum: higher gas
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => "0x12A05F200"
        })
      end)

      # Polygon: lower gas
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => "0x3B9ACA00"
        })
      end)

      assert {:ok, result} =
               GasComparisonPrism.handler(
                 %{chains: ["ethereum", "polygon"]},
                 nil
               )

      prices = result.gas_prices
      assert hd(prices).standard_gwei <= List.last(prices).standard_gwei
    end
  end
end
