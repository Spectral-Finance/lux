defmodule Lux.Lenses.Twitter.Automation.GetFollowersTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Twitter.Automation.GetFollowers

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves followers list" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/users/123456/followers"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [
            %{"id" => "f1", "name" => "Alice Developer", "username" => "alicedev",
              "description" => "Elixir enthusiast", "created_at" => "2020-01-01T00:00:00Z",
              "public_metrics" => %{"followers_count" => 500, "following_count" => 200}},
            %{"id" => "f2", "name" => "Bob Builder", "username" => "bobbuilder",
              "description" => "Building cool stuff", "created_at" => "2021-06-15T00:00:00Z",
              "public_metrics" => %{"followers_count" => 1200, "following_count" => 800}}
          ],
          "meta" => %{"result_count" => 2}
        }))
      end)

      assert {:ok, result} = GetFollowers.focus(%{"user_id" => "123456"}, %{})
      assert length(result.followers) == 2
      assert result.result_count == 2
      assert hd(result.followers).username == "alicedev"
    end

    test "returns empty list when user has no followers" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "meta" => %{"result_count" => 0}
        }))
      end)

      assert {:ok, result} = GetFollowers.focus(%{"user_id" => "newuser"}, %{})
      assert result.followers == []
    end

    test "supports pagination via next_token" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [%{"id" => "f3", "name" => "Charlie", "username" => "charlie",
            "public_metrics" => %{"followers_count" => 300, "following_count" => 100}}],
          "meta" => %{"result_count" => 1, "next_token" => "nextpage"}
        }))
      end)

      assert {:ok, result} = GetFollowers.focus(%{"user_id" => "123", "pagination_token" => "page1"}, %{})
      assert result.next_token == "nextpage"
    end

    test "handles rate limit error" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"title" => "Too Many Requests"}))
      end)

      assert {:error, :rate_limited} = GetFollowers.focus(%{"user_id" => "123"}, %{})
    end
  end
end
