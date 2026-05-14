defmodule Lux.Prisms.Telegram.Messaging.ProcessUpdateTest do
  use UnitCase, async: true

  alias Lux.Prisms.Telegram.Messaging.ProcessUpdate

  test "runs message processing through the prism" do
    assert {:ok, processed} =
             ProcessUpdate.run(%{
               update: %{
                 message: %{
                   message_id: 1,
                   text: "/start wallet-onboarding",
                   chat: %{id: 123, type: "private"}
                 }
               }
             })

    assert processed.command.command == "start"
    assert processed.deep_link.parts == ["wallet", "onboarding"]
  end

  test "accepts string keyed prism input" do
    assert {:ok, processed} =
             ProcessUpdate.run(%{
               "update" => %{"channel_post" => %{"message_id" => 3, "text" => "News"}},
               "bot_username" => "LuxBot"
             })

    assert processed.update_type == :channel_post
    assert processed.route == %{action: :channel_post, target: :broadcast}
  end

  test "exposes schema" do
    prism = ProcessUpdate.view()
    assert prism.input_schema.required == ["update"]
    assert Map.has_key?(prism.output_schema.properties, :command)
    assert Map.has_key?(prism.output_schema.properties, :callback)
  end
end
