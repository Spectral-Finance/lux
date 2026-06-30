defmodule Lux.Lenses.Etherscan.ContractCreationLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.ContractCreation

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response for a single contract" do
      # Set up the test parameters
      params = %{
        contractaddresses: "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "contract"
        assert query["action"] == "getcontractcreation"
        assert query["contractaddresses"] == "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "contractAddress" => "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F",
              "contractCreator" => "0x1234567890123456789012345678901234567890",
              "txHash" => "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
            }
          ]
        })
      end)

      # Call the lens
      result = ContractCreation.focus(params)

      # Verify the result
      assert {:ok, %{result: contracts}} = result
      assert length(contracts) == 1
      assert Enum.at(contracts, 0).contract_address == "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F"
      assert Enum.at(contracts, 0).creator_address == "0x1234567890123456789012345678901234567890"
      assert Enum.at(contracts, 0).tx_hash == "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
    end

    test "makes correct API call and processes the response for multiple contracts" do
      # Set up the test parameters
      params = %{
        contractaddresses: "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F,0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "contract"
        assert query["action"] == "getcontractcreation"
        assert query["contractaddresses"] == "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F,0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "contractAddress" => "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F",
              "contractCreator" => "0x1234567890123456789012345678901234567890",
              "txHash" => "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
            },
            %{
              "contractAddress" => "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45",
              "contractCreator" => "0x0987654321098765432109876543210987654321",
              "txHash" => "0x0987654321098765432109876543210987654321098765432109876543210987654321"
            }
          ]
        })
      end)

      # Call the lens
      result = ContractCreation.focus(params)

      # Verify the result
      assert {:ok, %{result: contracts}} = result
      assert length(contracts) == 2
      assert Enum.at(contracts, 0).contract_address == "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F"
      assert Enum.at(contracts, 1).contract_address == "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45"
    end

    test "handles error responses" do
      # Set up the test parameters
      params = %{
        contractaddresses: "0xinvalid",
        chainid: 1
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
      result = ContractCreation.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        contractaddresses: "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F",
        chainid: 1
      }

      # Call the function
      result = ContractCreation.before_focus(params)

      # Verify the result
      assert result.module == "contract"
      assert result.action == "getcontractcreation"
      assert result.contractaddresses == "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F"
      assert result.chainid == 1
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
            "contractAddress" => "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F",
            "contractCreator" => "0x1234567890123456789012345678901234567890",
            "txHash" => "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
          }
        ]
      }

      # Call the function
      result = ContractCreation.after_focus(response)

      # Verify the result
      assert {:ok, %{result: contracts}} = result
      assert length(contracts) == 1
      assert Enum.at(contracts, 0).contract_address == "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F"
      assert Enum.at(contracts, 0).creator_address == "0x1234567890123456789012345678901234567890"
      assert Enum.at(contracts, 0).tx_hash == "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = ContractCreation.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end
