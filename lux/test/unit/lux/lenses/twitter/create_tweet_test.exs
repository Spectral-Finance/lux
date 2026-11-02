defmodule Lux.Lenses.Twitter.Tweets.CreateTweetTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Twitter.Tweets.CreateTweet

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "schema validation" do
    test "validates required parameters" do
      assert {:error, errors} = CreateTweet.focus(%{})
      assert is_list(errors)
    end
  end

  describe "focus/2" do
    test "successfully posts tweet via lens" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          201,
          Jason.encode!(%{
            "data" => %{
              "id" => "1890000000000000000",
              "text" => "Posting through Lux lens!"
            }
          })
        )
      end)

      assert {:ok, result} =
               CreateTweet.focus(%{"text" => "Posting through Lux lens!"}, %{})

      assert result.id == "1890000000000000000"
      assert result.text == "Posting through Lux lens!"
    end
  end
end
