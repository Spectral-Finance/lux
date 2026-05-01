defmodule Lux.Prisms.Discord.MessagesTest do
  use ExUnit.Case, async: true

  describe "MessageHistory/1" do
    test "retrieves message history with valid channel_id" do
      params = %{channel_id: "123456789", limit: 25}
      result = Lux.Prisms.Discord.Messages.MessageHistory.handler(params, %{name: "TestAgent"})
      assert {:ok, %{channel_id: "123456789", messages: _, total: _}} = result
    end

    test "returns error with missing channel_id" do
      result = Lux.Prisms.Discord.Messages.MessageHistory.handler(%{}, %{name: "TestAgent"})
      assert {:error, _} = result
    end
  end
end
