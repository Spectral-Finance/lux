defmodule Lux.Prisms.Twitter.Automation.ManageFollowTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Automation.ManageFollow

  @agent %{name: "GrowthBot"}
  @source_id "source_user_123"
  @target_id "target_user_456"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully follows a user" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/users/#{@source_id}/following"
        {:ok, body, _} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["target_user_id"] == @target_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"following" => true, "pending_follow" => false}
        }))
      end)

      assert {:ok, result} = ManageFollow.handler(%{
        action: "follow",
        source_user_id: @source_id,
        target_user_id: @target_id
      }, @agent)

      assert result.success == true
      assert result.action == "follow"
      assert result.following == true
      assert result.target_user_id == @target_id
    end

    test "successfully unfollows a user" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/2/users/#{@source_id}/following/#{@target_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"following" => false}
        }))
      end)

      assert {:ok, result} = ManageFollow.handler(%{
        action: "unfollow",
        source_user_id: @source_id,
        target_user_id: @target_id
      }, @agent)

      assert result.success == true
      assert result.action == "unfollow"
      assert result.following == false
    end

    test "handles rate limit error" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"title" => "Too Many Requests"}))
      end)

      assert {:error, message} = ManageFollow.handler(%{
        action: "follow",
        source_user_id: @source_id,
        target_user_id: @target_id
      }, @agent)
      assert message =~ "Rate limit"
    end

    test "returns error for invalid action" do
      assert {:error, _} = ManageFollow.handler(%{
        action: "block",
        source_user_id: @source_id,
        target_user_id: @target_id
      }, @agent)
    end

    test "returns error for missing parameters" do
      assert {:error, _} = ManageFollow.handler(%{action: "follow"}, @agent)
    end
  end
end
