defmodule Lux.Integrations.Discord.CapabilitiesTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Discord.Capabilities

  test "builds valid thread creation payloads and summarizes author activity" do
    assert {:ok, %{name: "Governance Discussion", auto_archive_duration: 1440}} =
             Capabilities.build_thread_payload("  Governance Discussion  ")

    summary =
      Capabilities.summarize_message_activity([
        %{author: %{id: "u1"}},
        %{author: %{id: "u1"}},
        %{author: %{id: "u2"}}
      ])

    assert summary.total_messages == 3
    assert summary.active_authors == 2
  end
end
