defmodule Lux.Prisms.Telegram.Interactive.EditLiveLocationTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.EditLiveLocation

  @chat_id 123_456_789
  @message_id 42
  @inline_message_id "CAAqrxJRAqABAZaiqJ4sAJtvlCQI"
  @latitude 37.7858
  @longitude -122.4064
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully edits a live location with chat_id and message_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["message_id"] == @message_id
        assert decoded_body["latitude"] == @latitude
        assert decoded_body["longitude"] == @longitude

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "edit_date" => 1_617_123_459,
            "location" => %{
              "latitude" => @latitude,
              "longitude" => @longitude
            }
          }
        }))
      end)

      assert {:ok,
              %{updated: true, message_id: @message_id, chat_id: @chat_id, latitude: @latitude, longitude: @longitude}} =
               EditLiveLocation.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   latitude: @latitude,
                   longitude: @longitude,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully edits a live location with inline_message_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["inline_message_id"] == @inline_message_id
        assert decoded_body["latitude"] == @latitude
        assert decoded_body["longitude"] == @longitude

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{updated: true, inline_message_id: @inline_message_id, latitude: @latitude, longitude: @longitude}} =
               EditLiveLocation.handler(
                 %{
                   inline_message_id: @inline_message_id,
                   latitude: @latitude,
                   longitude: @longitude,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully edits a live location with optional parameters" do
      horizontal_accuracy = 65.4
      heading = 90
      proximity_alert_radius = 200

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["message_id"] == @message_id
        assert decoded_body["latitude"] == @latitude
        assert decoded_body["longitude"] == @longitude
        assert decoded_body["horizontal_accuracy"] == horizontal_accuracy
        assert decoded_body["heading"] == heading
        assert decoded_body["proximity_alert_radius"] == proximity_alert_radius

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "edit_date" => 1_617_123_459,
            "location" => %{
              "latitude" => @latitude,
              "longitude" => @longitude,
              "horizontal_accuracy" => horizontal_accuracy,
              "heading" => heading,
              "proximity_alert_radius" => proximity_alert_radius
            }
          }
        }))
      end)

      assert {:ok, %{updated: true, message_id: @message_id, chat_id: @chat_id}} =
               EditLiveLocation.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   latitude: @latitude,
                   longitude: @longitude,
                   horizontal_accuracy: horizontal_accuracy,
                   heading: heading,
                   proximity_alert_radius: proximity_alert_radius,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates required parameters" do
      result = EditLiveLocation.handler(%{longitude: @longitude}, @agent_ctx)
      assert result == {:error, "Missing or invalid latitude"}

      result = EditLiveLocation.handler(%{latitude: @latitude}, @agent_ctx)
      assert result == {:error, "Missing or invalid longitude"}

      result = EditLiveLocation.handler(%{latitude: @latitude, longitude: @longitude}, @agent_ctx)
      assert result == {:error, "Missing or invalid message identifier: Either (chat_id and message_id) or inline_message_id must be provided"}
    end

    test "validates optional parameters" do
      result = EditLiveLocation.handler(
        %{
          chat_id: @chat_id,
          message_id: @message_id,
          latitude: @latitude,
          longitude: @longitude,
          horizontal_accuracy: 2000,  # Outside valid range
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
      assert result == {:error, "horizontal_accuracy must be between 0 and 1500"}

      result = EditLiveLocation.handler(
        %{
          chat_id: @chat_id,
          message_id: @message_id,
          latitude: @latitude,
          longitude: @longitude,
          heading: 361,  # Outside valid range
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
      assert result == {:error, "heading must be between 1 and 360"}

      result = EditLiveLocation.handler(
        %{
          chat_id: @chat_id,
          message_id: @message_id,
          latitude: @latitude,
          longitude: @longitude,
          proximity_alert_radius: 0,  # Must be positive
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
      assert result == {:error, "proximity_alert_radius must be a positive integer"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: message to edit not found"
        }))
      end)

      assert {:error, "Failed to update live location: Bad Request: message to edit not found (HTTP 400)"} =
               EditLiveLocation.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   latitude: @latitude,
                   longitude: @longitude,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = EditLiveLocation.view()
      assert prism.input_schema.required == ["latitude", "longitude"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
      assert Map.has_key?(prism.input_schema.properties, :inline_message_id)
      assert Map.has_key?(prism.input_schema.properties, :latitude)
      assert Map.has_key?(prism.input_schema.properties, :longitude)
      assert Map.has_key?(prism.input_schema.properties, :horizontal_accuracy)
      assert Map.has_key?(prism.input_schema.properties, :heading)
      assert Map.has_key?(prism.input_schema.properties, :proximity_alert_radius)
    end

    test "validates output schema" do
      prism = EditLiveLocation.view()
      assert prism.output_schema.required == ["updated"]
      assert Map.has_key?(prism.output_schema.properties, :updated)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :inline_message_id)
      assert Map.has_key?(prism.output_schema.properties, :latitude)
      assert Map.has_key?(prism.output_schema.properties, :longitude)
    end
  end
end
