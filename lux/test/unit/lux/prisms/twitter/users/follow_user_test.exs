defmodule Lux.Prisms.Twitter.Users.FollowUserTest do
  @moduledoc """
  Test suite for the FollowUser prism.
  Verifies the prism can:
  - Follow a user
  - Handle pending follows (protected accounts)
  - Handle 401 unauthorized errors
  - Handle 403 forbidden errors
  - Handle 404 not found errors
  - Handle 429 rate limit errors
  - Accept string-keyed params
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Users.FollowUser

  @user_id "123456789"
  @target_user_id "987654321"
  @agent %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully follows a public user" do
      Req.Test.expect(FollowUser, fn conn ->
        assert conn.method == "POST"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["target_user_id"] == @target_user_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"following" => true, "pending_follow" => false}
        }))
      end)

      assert {:ok, result} = FollowUser.handler(
        %{user_id: @user_id, target_user_id: @target_user_id},
        @agent
      )

      assert result.following == true
      assert result.pending_follow == false
      assert result.target_user_id == @target_user_id
    end

    test "handles pending follow for protected account" do
      Req.Test.expect(FollowUser, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"following" => false, "pending_follow" => true}
        }))
      end)

      assert {:ok, result} = FollowUser.handler(
        %{user_id: @user_id, target_user_id: @target_user_id},
        @agent
      )

      assert result.following == false
      assert result.pending_follow == true
    end

    test "accepts string-keyed params" do
      Req.Test.expect(FollowUser, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"following" => true, "pending_follow" => false}
        }))
      end)

      assert {:ok, %{following: true}} = FollowUser.handler(
        %{"user_id" => @user_id, "target_user_id" => @target_user_id},
        @agent
      )
    end

    test "handles unauthorized error" do
      Req.Test.expect(FollowUser, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"title" => "Unauthorized"}))
      end)

      assert {:error, %{title: "Unauthorized"}} = FollowUser.handler(
        %{user_id: @user_id, target_user_id: @target_user_id},
        @agent
      )
    end

    test "handles forbidden error" do
      Req.Test.expect(FollowUser, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "detail" => "You have been blocked by this user"
        }))
      end)

      assert {:error, %{title: "Forbidden", detail: "You have been blocked by this user"}} =
               FollowUser.handler(%{user_id: @user_id, target_user_id: @target_user_id}, @agent)
    end

    test "handles not found error" do
      Req.Test.expect(FollowUser, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"title" => "Not Found"}))
      end)

      assert {:error, %{title: "Not Found", detail: detail}} =
               FollowUser.handler(%{user_id: @user_id, target_user_id: @target_user_id}, @agent)

      assert detail =~ @target_user_id
    end

    test "handles rate limit error" do
      Req.Test.expect(FollowUser, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"title" => "Too Many Requests"}))
      end)

      assert {:error, %{title: "Rate Limited"}} =
               FollowUser.handler(%{user_id: @user_id, target_user_id: @target_user_id}, @agent)
    end
  end
end
