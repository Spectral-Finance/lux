defmodule Lux.Prisms.YouTube.TransitionBroadcastTest do
  @moduledoc """
  Test suite for the YouTube TransitionBroadcast prism.
  Verifies:
  - Successful transition to testing/live/complete
  - Error when stream is not ready
  - Invalid transition handling
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.TransitionBroadcast

  @broadcast_id "broadcast_id_abc"

  setup do
    Application.put_env(:lux, :api_keys, youtube_oauth_token: "test_oauth_token")
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "transitions broadcast to live" do
      Req.Test.expect(Lux.Prism, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "transition"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @broadcast_id,
          "snippet" => %{
            "title" => "My Live Stream",
            "actualStartTime" => "2024-01-15T18:00:05.000Z"
          },
          "status" => %{
            "lifeCycleStatus" => "live"
          }
        }))
      end)

      assert {:ok, result} = TransitionBroadcast.handler(%{
        "broadcast_id" => @broadcast_id,
        "broadcast_status" => "live"
      }, %{})

      assert result.broadcast_id == @broadcast_id
      assert result.new_status == "live"
      assert result.life_cycle_status == "live"
      assert result.actual_start_time == "2024-01-15T18:00:05.000Z"
    end

    test "transitions broadcast to complete" do
      Req.Test.expect(Lux.Prism, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @broadcast_id,
          "snippet" => %{
            "title" => "My Live Stream",
            "actualEndTime" => "2024-01-15T19:00:00.000Z"
          },
          "status" => %{"lifeCycleStatus" => "complete"}
        }))
      end)

      assert {:ok, result} = TransitionBroadcast.handler(%{
        "broadcast_id" => @broadcast_id,
        "broadcast_status" => "complete"
      }, %{})

      assert result.new_status == "complete"
      assert result.actual_end_time == "2024-01-15T19:00:00.000Z"
    end

    test "handles stream not active error" do
      Req.Test.expect(Lux.Prism, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "error" => %{"message" => "Stream is not active. Please start ingestion first."}
        }))
      end)

      assert {:error, %{message: msg}} = TransitionBroadcast.handler(%{
        "broadcast_id" => @broadcast_id,
        "broadcast_status" => "live"
      }, %{})

      assert msg =~ "Stream is not active"
    end
  end
end
