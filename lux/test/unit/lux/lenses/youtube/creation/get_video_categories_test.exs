defmodule Lux.Lenses.YouTube.Creation.GetVideoCategoriesTest do
  @moduledoc """
  Test suite for the GetVideoCategories lens.
  These tests verify the lens's ability to:
  - Retrieve video categories for a given region
  - Handle default region (US) when none is specified
  - Handle YouTube API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Creation.GetVideoCategories

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves video categories for US region" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/videoCategories"

        query = URI.decode_query(conn.query_string)
        assert query["part"] == "snippet"
        assert query["regionCode"] == "US"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "kind" => "youtube#videoCategoryListResponse",
          "items" => [
            %{
              "id" => "1",
              "snippet" => %{
                "channelId" => "UCBR8-60-B28hp2BmDPdntcQ",
                "title" => "Film & Animation",
                "assignable" => true
              }
            },
            %{
              "id" => "10",
              "snippet" => %{
                "channelId" => "UCBR8-60-B28hp2BmDPdntcQ",
                "title" => "Music",
                "assignable" => true
              }
            },
            %{
              "id" => "29",
              "snippet" => %{
                "channelId" => "UCBR8-60-B28hp2BmDPdntcQ",
                "title" => "Nonprofits & Activism",
                "assignable" => false
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = GetVideoCategories.focus(%{"region_code" => "US"}, %{})
      assert result.count == 3
      [film, music, nonprofits] = result.categories
      assert film.id == "1"
      assert film.title == "Film & Animation"
      assert film.assignable == true
      assert music.id == "10"
      assert music.title == "Music"
      assert nonprofits.assignable == false
    end

    test "uses default region when none specified" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        query = URI.decode_query(conn.query_string)
        assert query["regionCode"] == "US"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "kind" => "youtube#videoCategoryListResponse",
          "items" => [
            %{
              "id" => "1",
              "snippet" => %{
                "channelId" => "UCBR8-60-B28hp2BmDPdntcQ",
                "title" => "Film & Animation",
                "assignable" => true
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = GetVideoCategories.focus(%{}, %{})
      assert result.count == 1
    end

    test "handles YouTube API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "error" => %{
            "code" => 400,
            "message" => "Invalid regionCode",
            "status" => "INVALID_ARGUMENT"
          }
        }))
      end)

      assert {:error, %{message: "Invalid regionCode", code: 400}} =
               GetVideoCategories.focus(%{"region_code" => "XX"}, %{})
    end
  end

  describe "schema validation" do
    test "has no required fields (region defaults to US)" do
      lens = GetVideoCategories.view()
      assert lens.schema.required == []
    end

    test "validates schema properties" do
      lens = GetVideoCategories.view()
      assert Map.has_key?(lens.schema.properties, :region_code)
      assert Map.has_key?(lens.schema.properties, :hl)
      assert lens.schema.properties.region_code.type == :string
    end
  end
end
