defmodule Lux.Lenses.YouTube.Growth.SearchCompetitorChannelsTest do
  @moduledoc """
  Test suite for the YouTube SearchCompetitorChannels lens.
  Verifies:
  - Successful channel search with keyword queries
  - Empty results handling
  - API error propagation
  - Required schema field validation
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Growth.SearchCompetitorChannels

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully returns competitor channels for a keyword" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "search"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => %{"kind" => "youtube#channel", "channelId" => "UCelixir001"},
              "snippet" => %{
                "channelTitle" => "ElixirSchool",
                "description" => "Learn Elixir and Phoenix Framework",
                "publishedAt" => "2017-03-15T00:00:00.000Z",
                "thumbnails" => %{
                  "high" => %{"url" => "https://yt3.ggpht.com/channel1.jpg"},
                  "default" => %{"url" => "https://yt3.ggpht.com/channel1_sm.jpg"}
                }
              }
            },
            %{
              "id" => %{"kind" => "youtube#channel", "channelId" => "UCelixir002"},
              "snippet" => %{
                "channelTitle" => "PhoenixDev",
                "description" => "Phoenix Framework tutorials",
                "publishedAt" => "2019-07-20T00:00:00.000Z",
                "thumbnails" => %{
                  "high" => %{"url" => "https://yt3.ggpht.com/channel2.jpg"}
                }
              }
            }
          ],
          "pageInfo" => %{"totalResults" => 150}
        }))
      end)

      assert {:ok, %{channels: channels, total_results: 150}} =
               SearchCompetitorChannels.focus(%{"query" => "elixir programming"}, %{})

      assert length(channels) == 2
      [first | _] = channels
      assert first.id == "UCelixir001"
      assert first.title == "ElixirSchool"
      assert first.description == "Learn Elixir and Phoenix Framework"
      assert first.thumbnail_url == "https://yt3.ggpht.com/channel1.jpg"
    end

    test "returns empty list when no channels match" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [],
          "pageInfo" => %{"totalResults" => 0}
        }))
      end)

      assert {:ok, %{channels: [], total_results: 0}} =
               SearchCompetitorChannels.focus(%{"query" => "noresultszxcvbn"}, %{})
    end

    test "handles API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "error" => %{"message" => "Invalid value for parameter 'order'"}
        }))
      end)

      assert {:error, %{message: "Invalid value for parameter 'order'"}} =
               SearchCompetitorChannels.focus(%{"query" => "test", "order" => "invalid"}, %{})
    end
  end

  describe "schema validation" do
    test "requires query parameter" do
      lens = SearchCompetitorChannels.view()
      assert "query" in lens.schema.required
      assert Map.has_key?(lens.schema.properties, :max_results)
      assert Map.has_key?(lens.schema.properties, :order)
    end
  end
end
