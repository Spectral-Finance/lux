defmodule Lux.Lenses.Allora.GetInferenceTest do
  @moduledoc """
  Test suite for the GetInference module.
  These tests verify the lens's ability to:
  - Fetch inference data by topic ID
  - Fetch price inference data for specific assets
  - Handle API errors appropriately
  - Transform response data correctly
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Allora.GetInference

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches inference by topic ID" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.query_string, "allora_topic_id%3D1")
        assert String.contains?(conn.query_string, "inference_value_type%3Duint256")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "signature" => "0xabc123",
            "inference_data" => %{
              "network_inference" => "1234567890",
              "network_inference_normalized" => "0.12345",
              "confidence_interval_percentiles" => ["0.1", "0.5", "0.9"],
              "confidence_interval_percentiles_normalized" => ["0.1", "0.5", "0.9"],
              "confidence_interval_values" => ["1200000000", "1234567890", "1300000000"],
              "confidence_interval_values_normalized" => ["0.12", "0.12345", "0.13"],
              "topic_id" => "1",
              "timestamp" => 1_679_529_600,
              "extra_data" => ""
            }
          }
        }))
      end)

      assert {:ok, result} = GetInference.focus(%{topic_id: 1}, %{})
      assert result.signature == "0xabc123"
      assert result.inference_data.network_inference == "1234567890"
      assert result.inference_data.network_inference_normalized == "0.12345"
      assert result.inference_data.confidence_interval_percentiles == ["0.1", "0.5", "0.9"]
      assert result.inference_data.topic_id == "1"
      assert result.inference_data.timestamp == 1_679_529_600
    end

    test "successfully fetches price inference" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "signature" => "0xdef456",
            "inference_data" => %{
              "network_inference" => "50000000000",
              "network_inference_normalized" => "50000.0",
              "confidence_interval_percentiles" => ["0.1", "0.5", "0.9"],
              "confidence_interval_percentiles_normalized" => ["0.1", "0.5", "0.9"],
              "confidence_interval_values" => ["49000000000", "50000000000", "51000000000"],
              "confidence_interval_values_normalized" => ["49000.0", "50000.0", "51000.0"],
              "topic_id" => "btc_5m",
              "timestamp" => 1_679_529_600,
              "extra_data" => ""
            }
          }
        }))
      end)

      assert {:ok, result} = GetInference.focus(%{
        asset: "BTC",
        timeframe: "5m"
      }, %{})
      assert result.signature == "0xdef456"
      assert result.inference_data.network_inference == "50000000000"
      assert result.inference_data.network_inference_normalized == "50000.0"
      assert result.inference_data.topic_id == "btc_5m"
    end

    test "handles API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{
            "message" => "Invalid API key"
          }
        }))
      end)

      assert {:error, %{"error" => %{"message" => "Invalid API key"}}} = GetInference.focus(%{topic_id: 1}, %{})
    end
  end

  describe "schema validation" do
    test "validates schema" do
      lens = GetInference.view()
      assert Map.has_key?(lens.schema.properties, :topic_id)
      assert Map.has_key?(lens.schema.properties, :asset)
      assert Map.has_key?(lens.schema.properties, :timeframe)
      assert Map.has_key?(lens.schema.properties, :signature_format)
      assert lens.schema.properties.asset.enum == ["BTC", "ETH"]
      assert lens.schema.properties.timeframe.enum == ["5m", "8h"]
    end
  end
end
