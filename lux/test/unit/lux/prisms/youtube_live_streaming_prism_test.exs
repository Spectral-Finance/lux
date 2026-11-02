defmodule Lux.Prisms.YouTubeLiveStreamingPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.YouTubeLiveStreamingPrism

  describe "handler/2" do
    test "executes get_auth_url action" do
      {:ok, response} =
        YouTubeLiveStreamingPrism.run(%{
          action: "get_auth_url",
          payload: %{client_id: "test_client"}
        })

      assert response.action == "get_auth_url"
      assert String.contains?(response.result.auth_url, "test_client")
    end

    test "executes create_broadcast action" do
      {:ok, response} =
        YouTubeLiveStreamingPrism.run(%{
          action: "create_broadcast",
          payload: %{title: "Prism Live Test"}
        })

      assert response.action == "create_broadcast"
      assert is_binary(response.result.broadcast_id)
      assert is_binary(response.result.rtmp_ingestion_url)
    end

    test "executes check_stream_health action" do
      {:ok, response} =
        YouTubeLiveStreamingPrism.run(%{
          action: "check_stream_health",
          payload: %{
            stream_id: "stream_xyz",
            telemetry: %{bitrate_kbps: 6000, fps: 60.0}
          }
        })

      assert response.action == "check_stream_health"
      assert response.result.health_status == :good
    end

    test "executes process_chat action" do
      items = [%{author: "Tester", text: "Hello from Prism!", super_chat_usd: 10.0}]

      {:ok, response} =
        YouTubeLiveStreamingPrism.run(%{
          action: "process_chat",
          payload: %{items: items}
        })

      assert response.action == "process_chat"
      assert length(response.result.messages) == 1
      assert length(response.result.super_chats) == 1
    end

    test "executes setup_automated_stream action" do
      {:ok, response} =
        YouTubeLiveStreamingPrism.run(%{
          action: "setup_automated_stream",
          payload: %{title: "Automated Live"}
        })

      assert response.action == "setup_automated_stream"
      assert response.result.status == :ready_for_encoder
    end

    test "handles unknown action with descriptive error" do
      {:error, reason} =
        YouTubeLiveStreamingPrism.run(%{
          action: "unsupported_live_action",
          payload: %{}
        })

      assert String.contains?(reason, "Unknown action: unsupported_live_action")
    end
  end

  describe "schema validation" do
    test "validates prism definition and schema" do
      prism = YouTubeLiveStreamingPrism.view()
      assert prism.name == "YouTube Live Streaming Prism"
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert Map.has_key?(prism.input_schema.properties, :payload)
      assert prism.output_schema.required == ["action", "result"]
    end
  end
end
