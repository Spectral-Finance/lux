defmodule Lux.Lenses.Etherscan.DailyAvgHashRateLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.DailyAvgHashRate

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: true
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response with ascending sort" do
      # Set up the test parameters
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-05",
        sort: "asc",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "stats"
        assert query["action"] == "dailyavghashrate"
        assert query["startdate"] == "2023-01-01"
        assert query["enddate"] == "2023-01-05"
        assert query["sort"] == "asc"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "UTCDate" => "2023-01-01",
              "networkHashRate" => "1234567.89"
            },
            %{
              "UTCDate" => "2023-01-02",
              "networkHashRate" => "1345678.90"
            },
            %{
              "UTCDate" => "2023-01-03",
              "networkHashRate" => "1456789.01"
            }
          ]
        })
      end)

      # Call the lens
      result = DailyAvgHashRate.focus(params)

      # Verify the result
      assert {:ok, %{result: hash_rate_data, daily_avg_hash_rate: hash_rate_data}} = result
      assert length(hash_rate_data) == 3

      # Verify first day's data
      first_day = Enum.at(hash_rate_data, 0)
      assert first_day.utc_date == "2023-01-01"
      assert first_day.hash_rate_ghs == 1_234_567.89

      # Verify second day's data
      second_day = Enum.at(hash_rate_data, 1)
      assert second_day.utc_date == "2023-01-02"
      assert second_day.hash_rate_ghs == 1_345_678.90

      # Verify third day's data
      third_day = Enum.at(hash_rate_data, 2)
      assert third_day.utc_date == "2023-01-03"
      assert third_day.hash_rate_ghs == 1_456_789.01
    end

    test "makes correct API call with descending sort" do
      # Set up the test parameters
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-05",
        sort: "desc",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["sort"] == "desc"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "UTCDate" => "2023-01-05",
              "networkHashRate" => "1678901.23"
            },
            %{
              "UTCDate" => "2023-01-04",
              "networkHashRate" => "1567890.12"
            },
            %{
              "UTCDate" => "2023-01-03",
              "networkHashRate" => "1456789.01"
            }
          ]
        })
      end)

      # Call the lens
      result = DailyAvgHashRate.focus(params)

      # Verify the result
      assert {:ok, %{result: hash_rate_data}} = result
      assert length(hash_rate_data) == 3
      assert Enum.at(hash_rate_data, 0).utc_date == "2023-01-05"
      assert Enum.at(hash_rate_data, 2).utc_date == "2023-01-03"
    end

    test "handles error responses for invalid date format" do
      # Set up the test parameters with invalid date format
      params = %{
        startdate: "01-01-2023", # Invalid format
        enddate: "2023-01-05",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid date format"
        })
      end)

      # Call the lens
      result = DailyAvgHashRate.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid date format"}} = result
    end

    test "handles Pro API key errors" do
      # Set up test API key without Pro access
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: false
      ])

      # Set up the test parameters
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-05",
        chainid: 1
      }

      # Expect an ArgumentError to be raised
      assert_raise ArgumentError, "This endpoint requires an Etherscan Pro API key.", fn ->
        DailyAvgHashRate.focus(params)
      end
    end

    test "handles empty results" do
      # Set up the test parameters
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-05",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an empty result
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "No data found"
        })
      end)

      # Call the lens
      result = DailyAvgHashRate.focus(params)

      # Verify the result
      assert {:ok, %{result: hash_rate_data, daily_avg_hash_rate: hash_rate_data}} = result
      assert hash_rate_data == []
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly with defaults" do
      # Temporarily set Pro API key to true for this test
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: true
      ])

      # Set up the test parameters without sort
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-05",
        chainid: 1
      }

      # Call the function
      result = DailyAvgHashRate.before_focus(params)

      # Verify the result
      assert result.module == "stats"
      assert result.action == "dailyavghashrate"
      assert result.startdate == "2023-01-01"
      assert result.enddate == "2023-01-05"
      assert result.sort == "asc"
      assert result.chainid == 1
    end

    test "prepares parameters correctly with custom values" do
      # Temporarily set Pro API key to true for this test
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: true
      ])

      # Set up the test parameters with sort
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-05",
        sort: "desc",
        chainid: 1
      }

      # Call the function
      result = DailyAvgHashRate.before_focus(params)

      # Verify the result
      assert result.module == "stats"
      assert result.action == "dailyavghashrate"
      assert result.startdate == "2023-01-01"
      assert result.enddate == "2023-01-05"
      assert result.sort == "desc"
      assert result.chainid == 1
    end

    test "raises error when Pro API key is not available" do
      # Temporarily set Pro API key to false
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: false
      ])

      # Set up the test parameters
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-05",
        chainid: 1
      }

      # Expect an error to be raised
      assert_raise ArgumentError, "This endpoint requires an Etherscan Pro API key.", fn ->
        DailyAvgHashRate.before_focus(params)
      end
    end
  end

  describe "after_focus/1" do
    test "processes successful response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => [
          %{
            "UTCDate" => "2023-01-01",
            "networkHashRate" => "1234567.89"
          },
          %{
            "UTCDate" => "2023-01-02",
            "networkHashRate" => "1345678.90"
          }
        ]
      }

      # Call the function
      result = DailyAvgHashRate.after_focus(response)

      # Verify the result
      assert {:ok, %{result: hash_rate_data, daily_avg_hash_rate: hash_rate_data}} = result
      assert length(hash_rate_data) == 2
      assert Enum.at(hash_rate_data, 0).utc_date == "2023-01-01"
      assert Enum.at(hash_rate_data, 0).hash_rate_ghs == 1_234_567.89
      assert Enum.at(hash_rate_data, 1).utc_date == "2023-01-02"
      assert Enum.at(hash_rate_data, 1).hash_rate_ghs == 1_345_678.90
    end

    test "processes empty result" do
      # Create a mock response with no data found
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "No data found"
      }

      # Call the function
      result = DailyAvgHashRate.after_focus(response)

      # Verify the result
      assert {:ok, %{result: hash_rate_data, daily_avg_hash_rate: hash_rate_data}} = result
      assert hash_rate_data == []
    end

    test "processes Pro API key error" do
      # Create a mock Pro API key error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "This endpoint requires a Pro subscription"
      }

      # Call the function
      result = DailyAvgHashRate.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}} = result
    end

    test "processes general error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid date format"
      }

      # Call the function
      result = DailyAvgHashRate.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid date format"}} = result
    end
  end
end
