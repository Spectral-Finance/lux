defmodule Lux.Lenses.Twitter.Users.GetUserTest do
  @moduledoc """
  Test suite for the GetUser lens.
  Verifies the lens can:
  - Retrieve a user by ID with Bearer token auth
  - Return transformed user profile data
  - Handle public_metrics expansion
  - Handle Twitter API errors (not found, unauthorized)
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Twitter.Users.GetUser

  @user_id "2244994945"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves a user by ID" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/users/:user_id"
        assert [auth] = Plug.Conn.get_req_header(conn, "authorization")
        assert String.starts_with?(auth, "Bearer ")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @user_id,
            "name" => "Twitter Dev",
            "username" => "TwitterDev",
            "description" => "The voice of the X Platform developer community"
          }
        }))
      end)

      assert {:ok, user} = GetUser.focus(%{"user_id" => @user_id}, %{})
      assert user.id == @user_id
      assert user.name == "Twitter Dev"
      assert user.username == "TwitterDev"
      assert user.description == "The voice of the X Platform developer community"
    end

    test "retrieves user with public_metrics when requested" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @user_id,
            "name" => "Twitter Dev",
            "username" => "TwitterDev",
            "public_metrics" => %{
              "followers_count" => 571234,
              "following_count" => 2048,
              "tweet_count" => 14052,
              "listed_count" => 1672
            }
          }
        }))
      end)

      assert {:ok, user} = GetUser.focus(
        %{"user_id" => @user_id, "user_fields" => "public_metrics"},
        %{}
      )
      assert user.public_metrics.followers_count == 571234
      assert user.public_metrics.following_count == 2048
      assert user.public_metrics.tweet_count == 14052
    end

    test "handles user not found error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "errors" => [%{
            "title" => "Not Found Error",
            "detail" => "Could not find user with id: [9999999999]",
            "type" => "https://api.twitter.com/2/problems/resource-not-found"
          }]
        }))
      end)

      assert {:error, %{title: "Not Found Error"}} = GetUser.focus(
        %{"user_id" => "9999999999"},
        %{}
      )
    end

    test "handles unexpected response format" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"unexpected" => "format"}))
      end)

      assert {:error, %{title: "Unexpected response"}} = GetUser.focus(
        %{"user_id" => @user_id},
        %{}
      )
    end

    test "includes optional fields when present" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @user_id,
            "name" => "Test User",
            "username" => "testuser",
            "verified" => true,
            "profile_image_url" => "https://pbs.twimg.com/profile_images/test/photo.jpg",
            "created_at" => "2007-03-01T00:00:00.000Z",
            "location" => "San Francisco, CA"
          }
        }))
      end)

      assert {:ok, user} = GetUser.focus(%{"user_id" => @user_id}, %{})
      assert user.verified == true
      assert user.location == "San Francisco, CA"
      assert user.created_at == "2007-03-01T00:00:00.000Z"
    end

    test "omits nil optional fields from result" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @user_id,
            "name" => "Minimal User",
            "username" => "minimaluser"
          }
        }))
      end)

      assert {:ok, user} = GetUser.focus(%{"user_id" => @user_id}, %{})
      refute Map.has_key?(user, :public_metrics)
      refute Map.has_key?(user, :description)
      refute Map.has_key?(user, :location)
    end
  end

  describe "schema validation" do
    test "validates required user_id field" do
      lens = GetUser.view()
      assert lens.schema.required == ["user_id"]
    end

    test "has correct lens URL" do
      lens = GetUser.view()
      assert lens.url == "https://api.twitter.com/2/users/:user_id"
    end

    test "uses GET method" do
      lens = GetUser.view()
      assert lens.method == :get
    end
  end
end
