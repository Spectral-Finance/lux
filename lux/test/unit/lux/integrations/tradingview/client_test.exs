defmodule Lux.Integrations.TradingView.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.TradingView.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "scan/3" do
    test "makes correct POST request and returns data" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["symbols"]["tickers"] == ["NASDAQ:TSLA"]
        assert is_list(decoded["columns"])

        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.32, 0.45, 0.12]
            }
          ]
        })
      end)

      body = Client.build_scan_body(
        ["NASDAQ:TSLA"],
        ["Recommend.All", "Recommend.MA", "Recommend.Other"],
        "1d"
      )

      assert {:ok, response} = Client.scan("america", body)
      assert is_map(response)
      assert is_list(response["data"])
    end

    test "handles error responses" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Internal error"}))
      end)

      body = Client.build_scan_body(["NASDAQ:TSLA"], ["close"], "1d")
      assert {:error, _} = Client.scan("america", body)
    end
  end

  describe "build_scan_body/3" do
    test "builds correct body for daily interval" do
      body = Client.build_scan_body(["NASDAQ:TSLA"], ["RSI", "MACD.macd"], "1d")

      assert body.symbols.tickers == ["NASDAQ:TSLA"]
      assert body.columns == ["RSI", "MACD.macd"]
    end

    test "builds correct body with interval suffix" do
      body = Client.build_scan_body(["BINANCE:BTCUSD"], ["RSI", "close"], "4h")

      assert body.columns == ["RSI|240", "close|240"]
    end

    test "supports multiple tickers" do
      body = Client.build_scan_body(
        ["NASDAQ:TSLA", "NASDAQ:AAPL"],
        ["Recommend.All"],
        "1d"
      )

      assert length(body.symbols.tickers) == 2
    end
  end

  describe "parse_scan_response/2" do
    test "parses valid response into ticker-keyed map" do
      response = %{
        "data" => [
          %{
            "s" => "NASDAQ:TSLA",
            "d" => [0.32, 58.5, 2.15]
          }
        ]
      }

      columns = ["Recommend.All", "RSI", "MACD.macd"]
      result = Client.parse_scan_response(response, columns)

      assert Map.has_key?(result, "NASDAQ:TSLA")
      ticker_data = result["NASDAQ:TSLA"]
      assert ticker_data["Recommend.All"] == 0.32
      assert ticker_data["RSI"] == 58.5
      assert ticker_data["MACD.macd"] == 2.15
    end

    test "strips interval suffix from column names" do
      response = %{
        "data" => [
          %{
            "s" => "NASDAQ:TSLA",
            "d" => [0.32, 58.5]
          }
        ]
      }

      columns = ["Recommend.All|60", "RSI|60"]
      result = Client.parse_scan_response(response, columns)

      ticker_data = result["NASDAQ:TSLA"]
      assert ticker_data["Recommend.All"] == 0.32
      assert ticker_data["RSI"] == 58.5
    end

    test "handles multiple tickers" do
      response = %{
        "data" => [
          %{"s" => "NASDAQ:TSLA", "d" => [0.32]},
          %{"s" => "NASDAQ:AAPL", "d" => [0.55]}
        ]
      }

      columns = ["Recommend.All"]
      result = Client.parse_scan_response(response, columns)

      assert result["NASDAQ:TSLA"]["Recommend.All"] == 0.32
      assert result["NASDAQ:AAPL"]["Recommend.All"] == 0.55
    end

    test "returns empty map for invalid response" do
      assert Client.parse_scan_response(%{}, ["RSI"]) == %{}
      assert Client.parse_scan_response(nil, ["RSI"]) == %{}
    end
  end
end
