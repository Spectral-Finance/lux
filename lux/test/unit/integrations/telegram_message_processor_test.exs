defmodule Lux.Integrations.Telegram.MessageProcessorTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Telegram.MessageProcessor

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Telegram.MessageProcessor.process(%{})
    assert {:ok, %{verified: true, issue: 63}} = Telegram.MessageProcessor.process(%{active: true})
    assert {:ok, 95.0} = Telegram.MessageProcessor.compute_efficiency_score(100, 100, 500)
  end
end
