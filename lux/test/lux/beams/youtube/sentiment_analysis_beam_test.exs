defmodule Lux.Beams.YouTube.SentimentAnalysisBeamTest do
  use ExUnit.Case, async: false
  alias Lux.Beams.YouTube.SentimentAnalysisBeam
  import Mock

  test "returns correct sentiment from LLM" do
    mock_response = {:ok, %Lux.LLM.Response{content: "spam"}}
    with_mock Lux.LLM, [call: fn _prompt, _tools, _opts -> mock_response end] do
      assert {:ok, result, _log} = SentimentAnalysisBeam.run(%{text: "Click this link!"})
      assert result.sentiment == :spam
    end
  end
end
