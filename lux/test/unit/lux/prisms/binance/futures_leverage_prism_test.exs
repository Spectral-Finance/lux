defmodule Lux.Prisms.Binance.FuturesLeveragePrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Binance.FuturesLeveragePrism

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    Application.put_env(:lux, :api_keys,
      binance_api_key: "test-api-key",
      binance_secret_key: "test-secret-key"
    )
    :ok
  end

  describe "handler/2 - set_leverage" do
    test "successfully sets leverage" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/fapi/v1/leverage"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "symbol" => "BTCUSDT",
          "leverage" => 10,
          "maxNotionalValue" => "1000000"
        }))
      end)

      assert {:ok, %{status: "success", result: result}} =
               FuturesLeveragePrism.handler(
                 %{
                   action: "set_leverage",
                   symbol: "BTCUSDT",
                   leverage: 10,
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert result.symbol == "BTCUSDT"
      assert result.leverage == 10
    end

    test "handles API error for set_leverage" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => -4028,
          "msg" => "Leverage is not valid."
        }))
      end)

      assert {:error, msg} =
               FuturesLeveragePrism.handler(
                 %{
                   action: "set_leverage",
                   symbol: "BTCUSDT",
                   leverage: 200,
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert msg =~ "Binance API error"
    end
  end

  describe "handler/2 - set_margin_type" do
    test "successfully sets margin type" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/fapi/v1/marginType"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "code" => 200,
          "msg" => "success"
        }))
      end)

      assert {:ok, %{status: "success", result: %{message: "success"}}} =
               FuturesLeveragePrism.handler(
                 %{
                   action: "set_margin_type",
                   symbol: "ETHUSDT",
                   margin_type: "ISOLATED",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )
    end

    test "handles already-set margin type error" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => -4046,
          "msg" => "No need to change margin type."
        }))
      end)

      assert {:error, msg} =
               FuturesLeveragePrism.handler(
                 %{
                   action: "set_margin_type",
                   symbol: "ETHUSDT",
                   margin_type: "CROSSED",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert msg =~ "Margin type already set"
    end
  end

  describe "handler/2 - unknown action" do
    test "returns error for unknown action" do
      assert {:error, msg} =
               FuturesLeveragePrism.handler(
                 %{action: "invalid_action", symbol: "BTCUSDT"},
                 @agent_ctx
               )

      assert msg =~ "Unknown action"
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = FuturesLeveragePrism.view()
      assert prism.input_schema.required == ["action", "symbol"]
      assert Map.has_key?(prism.input_schema.properties, :leverage)
      assert Map.has_key?(prism.input_schema.properties, :margin_type)
    end

    test "validates output schema" do
      prism = FuturesLeveragePrism.view()
      assert prism.output_schema.required == ["status", "result"]
    end
  end
end
