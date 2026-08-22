defmodule Lux.Binance.IntegrationTest do
  use ExUnit.Case, async: false
  
  alias Lux.Binance.Client
  alias Lux.Binance.WebSocket.Client, as: WSClient

  @moduletag :integration

  describe "Public REST API Integration" do
    test "hits Spot testnet/public endpoint successfully" do
      # Ping endpoint doesn't require authentication
      assert {:ok, %{}} = Client.request(:get, :spot, "/api/v3/ping", %{}, testnet: true)
    end

    test "hits Futures testnet/public endpoint successfully" do
      assert {:ok, %{}} = Client.request(:get, :futures, "/fapi/v1/ping", %{}, testnet: true)
    end
    
    test "fetches spot exchange info" do
      assert {:ok, %{"timezone" => _, "serverTime" => _}} = Client.request(:get, :spot, "/api/v3/exchangeInfo")
    end
  end

  describe "WebSocket Live Integration" do
    test "connects to public stream and receives ping/pong or event" do
      # Using a very high volume stream to ensure we get a message quickly
      {:ok, pid} = WSClient.start_link(subscriber: self(), streams: ["btcusdt@trade"])
      
      # Should receive subscription confirmation
      assert_receive {:ws_subscribed, %{"method" => "SUBSCRIBE"}}, 5000
      
      # Since BTC trades happen constantly, we should get a trade event or at least stay alive
      assert_receive {:ws_event, %{"e" => "trade", "s" => "BTCUSDT"}}, 5000
      
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
