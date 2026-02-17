defmodule Lux.Prisms.Hyperliquid.LiquidationMonitoringTest do
  use ExUnit.Case, async: true

  test "monitors liquidations on Hyperliquid" do
    # Mock the necessary functions and configurations for testing
    Application.put_env(:lux, :hyperliquid_private_key, "mocked_private_key")
    Application.put_env(:lux, :hyperliquid_address, "mocked_address")

    # Define a mock response from Hyperliquid
    mock_response = %{
      "status" => "success",
      "liquidation_data" => %{
        # Mock liquidation data
      }
    }

    # Mock the HTTP request to Hyperliquid
    allow(Hyperliquid.HTTPClient, :post, fn _url, _body, _headers ->
      {:ok, mock_response}
    end)

    # Call the function to be tested
    result = Lux.Prisms.Hyperliquid.LiquidationMonitoringPrism.run(%{
      coin: "ETH",
      is_buy: true,
      sz: 0.0051,
      limit_px: 2800.0,
      order_type: %{limit: %{tif: "Gtc"}},
      reduce_only: false,
      vault_address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
    })

    # Assert the expected result
    assert {:ok, %{"status" => "success", "liquidation_data" => _}} = result
  end
end