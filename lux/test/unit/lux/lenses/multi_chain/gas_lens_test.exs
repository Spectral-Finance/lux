defmodule Lux.Lenses.MultiChain.GasLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.MultiChain.GasLens

  setup do
    Application.put_env(:lux, :api_keys, etherscan: "test_api_key", etherscan_pro: false)
    Req.Test.verify_on_exit!()
  end

  describe "view/0" do
    test "returns a lens with correct configuration" do
      lens = GasLens.view()
      assert lens.name == "MultiChain.GasLens"
      assert lens.method == :get
    end
  end

  describe "focus/2" do
    test "fetches gas oracle data" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.params["module"] == "gastracker"
        assert conn.params["action"] == "gasoracle"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "SafeGasPrice" => "20",
            "ProposeGasPrice" => "25",
            "FastGasPrice" => "35",
            "suggestBaseFee" => "18.5"
          }
        })
      end)

      assert {:ok, %{result: result}} = GasLens.focus(%{chainid: 1})
      assert result["SafeGasPrice"] == "20"
      assert result["ProposeGasPrice"] == "25"
      assert result["FastGasPrice"] == "35"
    end
  end
end
