defmodule Lux.Prisms.Twitter.Automation.EvaluateRulesTest do
  use UnitCase, async: true

  alias Lux.Prisms.Twitter.Automation.EvaluateRules

  test "returns engagement action plans" do
    assert {:ok, payload} =
             EvaluateRules.handler(
               %{
                 events: [%{id: "e1", type: "mention", text: "please help", author_id: "u1"}],
                 rules: [%{name: "support", action: "reply", conditions: %{contains: ["help"]}}],
                 self_author_ids: []
               },
               nil
             )

    assert [%{action: :reply, target_id: "e1", rule: "support"}] = payload.actions
    assert payload.summary.matched_actions == 1
  end
end
