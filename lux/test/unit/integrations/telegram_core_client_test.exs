defmodule Lux.Integrations.Telegram.CoreClientTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Telegram.CoreClient

  test "builds Telegram sendMessage payload with parse_mode" do
    assert {:ok, %{chat_id: 12345, text: "Alert", parse_mode: "HTML"}} =
             CoreClient.build_send_message_payload(12345, "Alert", parse_mode: "HTML")
  end
end
