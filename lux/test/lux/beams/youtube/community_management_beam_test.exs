defmodule Lux.Beams.YouTube.CommunityManagementBeamTest do
  use ExUnit.Case, async: false
  alias Lux.Beams.YouTube.CommunityManagementBeam
  import Mock

  @tag :unit
  test "end-to-end community management flow" do
    comments_response = %{
      status: 200,
      body: %{
        "items" => [
          %{"id" => "c1", "snippet" => %{"topLevelComment" => %{"snippet" => %{"textOriginal" => "Great video!"}}}},
          %{"id" => "c2", "snippet" => %{"topLevelComment" => %{"snippet" => %{"textOriginal" => "Buy followers at http://spam.com"}}}}
        ]
      }
    }

    moderation_response = %{status: 204, body: ""}
    reply_response = %{status: 200, body: %{"id" => "r1"}}

    with_mocks([
      {Req, [:passthrough], [
        request: fn req, _opts ->
          cond do
            String.contains?(req.url |> URI.to_string(), "commentThreads") -> {:ok, comments_response}
            String.contains?(req.url |> URI.to_string(), "setModerationStatus") -> {:ok, moderation_response}
            String.contains?(req.url |> URI.to_string(), "comments") -> {:ok, reply_response}
            true -> {:error, "Unknown URL"}
          end
        end
      ]},
      {Lux.LLM.OpenAI, [], [
        call: fn prompt, _tools, _opts ->
          IO.inspect(prompt, label: "MOCK_PROMPT")
          if is_binary(prompt) and String.contains?(prompt, "Great video!") do
            {:ok, %Lux.LLM.Response{content: "positive"}}
          else
            {:ok, %Lux.LLM.Response{content: "spam"}}
          end
        end
      ]}
    ]) do
      assert {:ok, result, _log} = CommunityManagementBeam.run(%{videoId: "vid123"})
        
        # Result will be the output of the last step, which is process_comments
        assert length(result) == 2
        
        [first, second] = result
        
        assert first.id == "c1"
        assert first.sentiment == :positive
        assert {:ok, _} = first.action

        assert second.id == "c2"
        assert second.sentiment == :spam
        assert {:ok, _} = second.action
      end
    end
  end
