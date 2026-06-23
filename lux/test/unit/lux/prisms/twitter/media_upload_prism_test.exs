defmodule Lux.Prisms.Twitter.MediaUploadPrismTest do
  use ExUnit.Case, async: false
  import Mock
  alias Lux.Prisms.Twitter.MediaUploadPrism

  describe "MediaUploadPrism" do
    test "successfully performs 3-step media upload" do
      input = %{
        "token" => "test_token",
        "media_data" => "binary_data",
        "media_type" => "image/jpeg"
      }

      with_mock Req, [
        post: fn url, opts -> 
          assert url == "https://upload.twitter.com/1.1/media/upload.json"
          assert Enum.member?(opts[:headers], {"Authorization", "Bearer test_token"})
          
          cond do
            # INIT request
            opts[:form][:command] == "INIT" ->
              assert opts[:form][:media_type] == "image/jpeg"
              assert opts[:form][:total_bytes] == byte_size("binary_data")
              {:ok, %Req.Response{status: 202, body: %{"media_id_string" => "123456"}}}

            # FINALIZE request
            opts[:form][:command] == "FINALIZE" ->
              assert opts[:form][:media_id] == "123456"
              {:ok, %Req.Response{status: 201, body: %{"media_id_string" => "123456"}}}

            # APPEND request (uses multipart)
            opts[:form] && opts[:form][:command] == "APPEND" ->
              # Depending on how Req.post multipart is constructed in implementation
              {:ok, %Req.Response{status: 204, body: ""}}

            # APPEND request using raw multipart
            opts[:multipart] != nil ->
              # Just mock success for APPEND
              {:ok, %Req.Response{status: 204, body: ""}}
          end
        end
      ] do
        assert {:ok, %{media_id: "123456"}} = MediaUploadPrism.handler(input)
      end
    end
  end
end
