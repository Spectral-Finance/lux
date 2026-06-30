defmodule Lux.Lenses.Allora.GetTopicsTest do
  @moduledoc """
  Test suite for the GetTopics module.
  These tests verify the lens's ability to:
  - Fetch topics from the Allora API
  - Handle API errors appropriately
  - Transform response data correctly
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Allora.GetTopics

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches topics" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v2/allora/allora-testnet-1/topics"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "topics" => [
              %{
                "topic_id" => 1,
                "topic_name" => "BTC/USD",
                "description" => "Bitcoin price prediction",
                "epoch_length" => 300,
                "ground_truth_lag" => 60,
                "loss_method" => "rmse",
                "worker_submission_window" => 60,
                "worker_count" => 10,
                "reputer_count" => 3,
                "total_staked_allo" => 1000.0,
                "total_emissions_allo" => 100.0,
                "is_active" => true,
                "updated_at" => "2024-03-28T12:00:00Z"
              }
            ]
          }
        }))
      end)

      assert {:ok, [topic]} = GetTopics.focus(%{}, %{})
      assert topic.topic_id == 1
      assert topic.topic_name == "BTC/USD"
      assert topic.description == "Bitcoin price prediction"
      assert topic.epoch_length == 300
      assert topic.ground_truth_lag == 60
      assert topic.loss_method == "rmse"
      assert topic.worker_submission_window == 60
      assert topic.worker_count == 10
      assert topic.reputer_count == 3
      assert topic.total_staked_allo == 1000.0
      assert topic.total_emissions_allo == 100.0
      assert topic.is_active == true
      assert topic.updated_at == "2024-03-28T12:00:00Z"
    end

    test "handles API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v2/allora/allora-testnet-1/topics"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{
            "message" => "Invalid API key"
          }
        }))
      end)

      assert {:error, %{"error" => %{"message" => "Invalid API key"}}} = GetTopics.focus(%{}, %{})
    end
  end

  describe "schema validation" do
    test "validates schema" do
      lens = GetTopics.view()
      assert lens.schema.properties == %{}
      assert lens.schema.required == []
    end
  end
end
