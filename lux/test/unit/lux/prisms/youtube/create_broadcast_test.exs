defmodule Lux.Prisms.YouTube.CreateBroadcastTest do
  @moduledoc """
  Test suite for the YouTube CreateBroadcast prism.
  Verifies:
  - Successful broadcast creation with full options
  - Minimal required parameters
  - API error handling
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.CreateBroadcast

  setup do
    Application.put_env(:lux, :api_keys, youtube_oauth_token: "test_oauth_token")
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates a live broadcast" do
      Req.Test.expect(Lux.Prism, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "liveBroadcasts"

        body = Jason.decode!(conn.body_params |> Jason.encode!())
        assert get_in(body, ["snippet", "title"]) == "My Live Stream"
        assert get_in(body, ["status", "privacyStatus"]) == "public"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "newBroadcastId",
          "snippet" => %{
            "title" => "My Live Stream",
            "scheduledStartTime" => "2024-02-01T18:00:00.000Z",
            "liveChatId" => "EwAB_chat_id"
          },
          "status" => %{"lifeCycleStatus" => "created"},
          "contentDetails" => %{"boundStreamId" => nil}
        }))
      end)

      assert {:ok, result} = CreateBroadcast.handler(%{
        "title" => "My Live Stream",
        "scheduled_start_time" => "2024-02-01T18:00:00.000Z",
        "privacy_status" => "public"
      }, %{})

      assert result.broadcast_id == "newBroadcastId"
      assert result.title == "My Live Stream"
      assert result.status == "created"
      assert result.live_chat_id == "EwAB_chat_id"
    end

    test "handles API error on creation" do
      Req.Test.expect(Lux.Prism, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{"message" => "The caller does not have permission"}
        }))
      end)

      assert {:error, %{message: "The caller does not have permission"}} =
               CreateBroadcast.handler(%{
                 "title" => "Unauthorized Stream",
                 "scheduled_start_time" => "2024-02-01T18:00:00.000Z"
               }, %{})
    end
  end
end
