defmodule Lux.Prisms.TwitterCorePrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.TwitterCorePrism

  describe "handler/2 actions" do
    test "posts tweet via Prism" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{"data" => %{"id" => "98765", "text" => "Agent Tweet"}}))
      end

      {:ok, response} =
        TwitterCorePrism.run(%{
          action: "post_tweet",
          payload: %{
            text: "Agent Tweet",
            plug: plug,
            token: "mock_tok"
          }
        })

      assert response.action == "post_tweet"
      assert response.result["data"]["id"] == "98765"
    end

    test "deletes tweet via Prism" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => %{"deleted" => true}}))
      end

      {:ok, response} =
        TwitterCorePrism.run(%{
          action: "delete_tweet",
          payload: %{
            tweet_id: "98765",
            plug: plug,
            token: "mock_tok"
          }
        })

      assert response.action == "delete_tweet"
      assert response.result["data"]["deleted"] == true
    end

    test "gets tweet via Prism" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "98765",
              "text" => "Target Tweet"
            }
          })
        )
      end

      {:ok, response} =
        TwitterCorePrism.run(%{
          action: "get_tweet",
          payload: %{
            tweet_id: "98765",
            plug: plug,
            token: "mock_tok"
          }
        })

      assert response.action == "get_tweet"
      assert response.result["data"]["id"] == "98765"
    end

    test "posts thread via Prism" do
      {:ok, pid} = Agent.start_link(fn -> 0 end)

      plug = fn conn ->
        count = Agent.get_and_update(pid, &{&1 + 1, &1 + 1})

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{"data" => %{"id" => "id_#{count}", "text" => "part #{count}"}}))
      end

      {:ok, response} =
        TwitterCorePrism.run(%{
          action: "post_thread",
          payload: %{
            tweets: ["part 1", "part 2"],
            plug: plug,
            token: "mock_tok"
          }
        })

      assert response.action == "post_thread"
      assert length(response.result) == 2
    end

    test "looks up user via Prism" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "555",
              "username" => "lux_bot"
            }
          })
        )
      end

      {:ok, response} =
        TwitterCorePrism.run(%{
          action: "lookup_user",
          payload: %{
            username: "lux_bot",
            plug: plug,
            token: "mock_tok"
          }
        })

      assert response.action == "lookup_user"
      assert response.result["data"]["username"] == "lux_bot"
    end

    test "generates OAuth 2.0 PKCE url" do
      {:ok, response} =
        TwitterCorePrism.run(%{
          action: "generate_oauth_url",
          payload: %{
            client_id: "my_twitter_client_id",
            redirect_uri: "https://agent.example.com/oauth/twitter"
          }
        })

      assert response.action == "generate_oauth_url"
      assert String.contains?(response.result.url, "client_id=my_twitter_client_id")
      assert is_binary(response.result.code_verifier)
      assert is_binary(response.result.code_challenge)
    end

    test "handles unknown action" do
      assert {:error, reason} =
               TwitterCorePrism.run(%{
                 action: "unsupported_action"
               })

      assert String.contains?(reason, "Unknown action: unsupported_action")
    end
  end
end
