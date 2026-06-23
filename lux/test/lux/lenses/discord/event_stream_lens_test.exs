defmodule Lux.Lenses.Discord.EventStreamLensTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Discord.EventStreamLens

  describe "after_focus/1" do
    test "successfully decodes mock Gateway JSON payload" do
      payload = %{
        "op" => 0,
        "d" => %{
          "content" => "Hello, world!"
        },
        "s" => 42,
        "t" => "MESSAGE_CREATE"
      }

      assert {:ok, decoded} = EventStreamLens.after_focus(payload)
      assert decoded.op == 0
      assert decoded.data["content"] == "Hello, world!"
      assert decoded.sequence == 42
      assert decoded.type == "MESSAGE_CREATE"
    end
  end
end
