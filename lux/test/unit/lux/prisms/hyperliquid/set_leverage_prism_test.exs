defmodule Lux.Prisms.Hyperliquid.SetLeveragePrismTest do
  @moduledoc """
  Test suite for SetLeveragePrism.
  """

  use UnitAPICase, async: false

  import Mock

  alias Lux.Prisms.Hyperliquid.SetLeveragePrism

  describe "run/1" do
    test "successfully sets leverage" do
      input = %{
        "coin" => "ETH",
        "leverage" => 10,
        "margin_mode" => "cross"
      }

      with_mocks([
        {Lux.Config, [], [
          hyperliquid_account_key: fn -> "0x" <> String.duplicate("1", 64) end,
          hyperliquid_account_address: fn -> "0x0403369c02199a0cb827f4d6492927e9fa5668d5" end,
          hyperliquid_api_url: fn -> "https://api.hyperliquid.xyz" end
        ]},
        {Lux.Python, [], [
          import_package: fn _pkg -> {:ok, %{"success" => true}} end,
          eval!: fn _code, opts ->
            vars = Keyword.get(opts, :variables, %{})
            params = Map.get(vars, :params)
            %{
              "coin" => params["coin"],
              "leverage" => params["leverage"],
              "margin_mode" => Map.get(params, "margin_mode", "cross"),
              "result" => %{"status" => "ok"}
            }
          end
        ]}
      ]) do
        assert {:ok, response} = SetLeveragePrism.run(input)
        assert response.status == "success"
        assert response.leverage_result["coin"] == "ETH"
        assert response.leverage_result["leverage"] == 10
        assert response.leverage_result["margin_mode"] == "cross"
      end
    end
  end
end
