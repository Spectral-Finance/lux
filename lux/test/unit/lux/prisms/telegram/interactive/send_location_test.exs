defmodule Lux.Prisms.Telegram.Interactive.SendLocationTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.SendLocation

  @chat_id 123_456_789
  @latitude 37.7749
  @longitude -122.4194
  @message_id 42
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends a static location" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendLocation")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["latitude"] == @latitude
        assert decoded_body["longitude"] == @longitude

        # Ensure it doesn't include live location parameters
        refute Map.has_key?(decoded_body, "live_period")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "location" => %{
              "latitude" => @latitude,
              "longitude" => @longitude
            }
          }
        }))
      end)

      assert {:ok, result} = SendLocation.handler(
        %{
          chat_id: @chat_id,
          latitude: @latitude,
          longitude: @longitude,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert result.sent == true
      assert result.message_id == @message_id
      assert result.chat_id == @chat_id
      assert result.latitude == @latitude
      assert result.longitude == @longitude
      assert result.live_period == nil
    end

    test "successfully sends a live location" do
      live_period = 3600 # 1 hour

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendLocation")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["latitude"] == @latitude
        assert decoded_body["longitude"] == @longitude
        assert decoded_body["live_period"] == live_period

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "location" => %{
              "latitude" => @latitude,
              "longitude" => @longitude,
              "live_period" => live_period
            }
          }
        }))
      end)

      assert {:ok, result} = SendLocation.handler(
        %{
          chat_id: @chat_id,
          latitude: @latitude,
          longitude: @longitude,
          live_period: live_period,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert result.sent == true
      assert result.message_id == @message_id
      assert result.chat_id == @chat_id
      assert result.latitude == @latitude
      assert result.longitude == @longitude
      assert result.live_period == live_period
    end

    test "successfully sends a location with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendLocation")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["latitude"] == @latitude
        assert decoded_body["longitude"] == @longitude
        assert decoded_body["horizontal_accuracy"] == 100.0
        assert decoded_body["live_period"] == 3600
        assert decoded_body["heading"] == 90
        assert decoded_body["proximity_alert_radius"] == 200
        assert decoded_body["disable_notification"] == true
        assert decoded_body["protect_content"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id},
            "location" => %{
              "latitude" => @latitude,
              "longitude" => @longitude
            }
          }
        }))
      end)

      assert {:ok, _result} = SendLocation.handler(
        %{
          chat_id: @chat_id,
          latitude: @latitude,
          longitude: @longitude,
          horizontal_accuracy: 100.0,
          live_period: 3600,
          heading: 90,
          proximity_alert_radius: 200,
          disable_notification: true,
          protect_content: true,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
    end

    test "validates required parameters" do
      # Missing chat_id
      result = SendLocation.handler(%{
        latitude: @latitude,
        longitude: @longitude
      }, @agent_ctx)
      assert {:error, "Missing or invalid chat_id"} = result

      # Missing latitude
      result = SendLocation.handler(%{
        chat_id: @chat_id,
        longitude: @longitude
      }, @agent_ctx)
      assert {:error, "Missing or invalid latitude"} = result

      # Missing longitude
      result = SendLocation.handler(%{
        chat_id: @chat_id,
        latitude: @latitude
      }, @agent_ctx)
      assert {:error, "Missing or invalid longitude"} = result

      # Invalid latitude type
      result = SendLocation.handler(%{
        chat_id: @chat_id,
        latitude: "not a number",
        longitude: @longitude
      }, @agent_ctx)
      assert {:error, "Missing or invalid latitude"} = result
    end

    test "validates live_period range" do
      # live_period too small
      result = SendLocation.handler(%{
        chat_id: @chat_id,
        latitude: @latitude,
        longitude: @longitude,
        live_period: 30 # Minimum is 60
      }, @agent_ctx)
      assert {:error, "Invalid live_period: must be between 60 and 86400 seconds"} = result

      # live_period too large
      result = SendLocation.handler(%{
        chat_id: @chat_id,
        latitude: @latitude,
        longitude: @longitude,
        live_period: 100_000 # Maximum is 86400 (24 hours)
      }, @agent_ctx)
      assert {:error, "Invalid live_period: must be between 60 and 86400 seconds"} = result
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: latitude value is out of range"
        }))
      end)

      assert {:error, "Failed to send location: Bad Request: latitude value is out of range (HTTP 400)"} =
               SendLocation.handler(
                 %{
                   chat_id: @chat_id,
                   latitude: 200, # Invalid value
                   longitude: @longitude,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendLocation.view()
      assert prism.input_schema.required == ["chat_id", "latitude", "longitude"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :latitude)
      assert Map.has_key?(prism.input_schema.properties, :longitude)
      assert Map.has_key?(prism.input_schema.properties, :live_period)
      assert Map.has_key?(prism.input_schema.properties, :horizontal_accuracy)
      assert Map.has_key?(prism.input_schema.properties, :heading)
      assert Map.has_key?(prism.input_schema.properties, :proximity_alert_radius)
    end

    test "validates output schema" do
      prism = SendLocation.view()
      assert prism.output_schema.required == ["sent", "message_id", "latitude", "longitude"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :latitude)
      assert Map.has_key?(prism.output_schema.properties, :longitude)
      assert Map.has_key?(prism.output_schema.properties, :live_period)
    end
  end
end
