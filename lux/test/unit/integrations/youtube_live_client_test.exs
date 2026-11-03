defmodule Lux.Integrations.YouTube.LiveClientTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.YouTube.LiveClient

  test "builds valid live broadcast payload and validates privacy status" do
    assert {:ok, payload} =
             LiveClient.build_live_broadcast_payload(
               "Market Open Live Stream",
               "2026-11-05T14:00:00Z",
               "public"
             )

    assert payload.snippet.title == "Market Open Live Stream"
    assert {:error, :invalid_privacy_status} =
             LiveClient.build_live_broadcast_payload("Stream", "2026-11-05T14:00:00Z", "invalid")
  end
end
