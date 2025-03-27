defmodule Lux.Lenses.Etherscan.BalanceMultiLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.BalanceMulti

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        addresses: [
          "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
          "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
        ],
        chainid: 1,
        tag: "latest"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "balancemulti"
        assert query["address"] == "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045,0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
        assert query["tag"] == "latest"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "account" => "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
              "balance" => "123456789012345678"
            },
            %{
              "account" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
              "balance" => "987654321098765432"
            }
          ]
        })
      end)

      # Call the lens
      result = BalanceMulti.focus(params)

      # Verify the result
      assert {:ok, %{result: result_data}} = result
      assert is_list(result_data)
      assert length(result_data) == 2

      # Check first address data
      first_address = Enum.at(result_data, 0)
      assert first_address["account"] == "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
      assert first_address["balance"] == "123456789012345678"

      # Check second address data
      second_address = Enum.at(result_data, 1)
      assert second_address["account"] == "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
      assert second_address["balance"] == "987654321098765432"
    end

    test "handles error responses" do
      # Set up the test parameters with an invalid address
      params = %{
        addresses: [
          "0xinvalid",
          "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
        ],
        chainid: 1,
        tag: "latest"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid address format"
        })
      end)

      # Call the lens
      result = BalanceMulti.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end

    test "handles Pro API key errors" do
      # Set up the test parameters
      params = %{
        addresses: [
          "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
          "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
        ],
        chainid: 1,
        tag: "latest"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a Pro API key error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "This endpoint requires a Pro subscription"
        })
      end)

      # Call the lens
      result = BalanceMulti.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}} = result
    end

    test "handles too many addresses" do
      # Create a list of 21 addresses (exceeding the 20 limit)
      addresses = for _ <- 1..21, do: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"

      # Set up the test parameters
      params = %{
        addresses: addresses,
        chainid: 1,
        tag: "latest"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Max addresses limit exceeded"
        })
      end)

      # Call the lens
      result = BalanceMulti.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Max addresses limit exceeded"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        addresses: [
          "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
          "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
        ],
        chainid: 1,
        tag: "latest"
      }

      # Call the function
      result = BalanceMulti.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "balancemulti"
      assert result.address == "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045,0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
      assert result.chainid == 1
      assert result.tag == "latest"
    end

    test "joins multiple addresses with commas" do
      # Set up the test parameters with multiple addresses
      params = %{
        addresses: [
          "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
          "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
          "0x1234567890123456789012345678901234567890"
        ],
        chainid: 1,
        tag: "latest"
      }

      # Call the function
      result = BalanceMulti.before_focus(params)

      # Verify the result
      expected_address_string = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045,0x742d35Cc6634C0532925a3b844Bc454e4438f44e,0x1234567890123456789012345678901234567890"
      assert result.address == expected_address_string
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
            "account" => "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
            "balance" => "123456789012345678"
          },
          %{
            "account" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
            "balance" => "987654321098765432"
          }
        ]
      }

      # Call the function
      result = BalanceMulti.after_focus(response)

      # Verify the result
      assert {:ok, %{result: result_data}} = result
      assert is_list(result_data)
      assert length(result_data) == 2
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = BalanceMulti.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end
