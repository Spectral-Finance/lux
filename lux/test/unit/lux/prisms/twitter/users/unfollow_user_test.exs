defmodule Lux.Prisms.Twitter.Users.UnfollowUserTest do
  @moduledoc """
  Test suite for the UnfollowUser prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Users.UnfollowUser

  @user_id "123456789"
  @target_user_id "987654321"
  @agent %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully unfollows a user" do
      Req.Test.expect(UnfollowUser, fn conn ->
        assert conn.method == "DELETE"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"following" => false}
        }))
      end)

      assert {:ok, result} = UnfollowUser.handler(
        %{user_id: @user_id, target_user_id: @target_user_id},
        @agent
      )

      assert result.following == false
      assert result.target_user_id == @target_user_id
    end

    test "accepts string-keyed params" do
      Req.Test.expect(UnfollowUser, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"following" => false}
        }))
      end)

      assert {:ok, %{following: false}} = UnfollowUser.handler(
        %{"user_id" => @user_id, "target_user_id" => @target_user_id},
        @agent
      )
    end

    test "handles unauthorized error" do
      Req.Test.expect(UnfollowUser, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"title" => "Unauthorized"}))
      end)

      assert {:error, %{title: "Unauthorized"}} = UnfollowUser.handler(
        %{user_id: @user_id, target_user_id: @target_user_id},
        @agent
      )
    end

    test "handles not found error" do
      Req.Test.expect(UnfollowUser, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"title" => "Not Found"}))
      end)

      assert {:error, %{title: "Not Found", detail: detail}} =
               UnfollowUser.handler(%{user_id: @user_id, target_user_id: @target_user_id}, @agent)

      assert detail =~ @target_user_id
    end

    test "handles rate limit error" do
      Req.Test.expect(UnfollowUser, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"title" => "Too Many Requests"}))
      end)

      assert {:error, %{title: "Rate Limited"}} =
               UnfollowUser.handler(%{user_id: @user_id, target_user_id: @target_user_id}, @agent)
    end
  end
end
