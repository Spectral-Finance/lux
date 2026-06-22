defmodule Lux.Integration.Web3AuthFlowTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Web3Auth.SessionPrism

  @moduletag :integration

  describe "SessionPrism" do
    test "create and validate session" do
      # 1. Create session
      result = SessionPrism.run(%{
        "action" => "create",
        "address" => "0x1234567890123456789012345678901234567890",
        "ttl_seconds" => 3600
      })

      assert {:ok, session_data} = result
      assert session_data.address == "0x1234567890123456789012345678901234567890"
      assert is_binary(session_data.token)
      assert is_integer(session_data.expires_at)

      token = session_data.token

      # 2. Validate session
      validate_result = SessionPrism.run(%{
        "action" => "validate",
        "token" => token
      })

      assert {:ok, validated} = validate_result
      assert validated.valid == true
      assert validated.address == "0x1234567890123456789012345678901234567890"
    end
    
    test "validate fails with tampered token" do
      result = SessionPrism.run(%{
        "action" => "create",
        "address" => "0x1234567890123456789012345678901234567890",
        "ttl_seconds" => 3600
      })
      assert {:ok, session_data} = result
      
      [payload, _sig] = String.split(session_data.token, ".")
      tampered_token = payload <> ".tamperedsig"
      
      validate_result = SessionPrism.run(%{
        "action" => "validate",
        "token" => tampered_token
      })
      
      assert {:ok, validated} = validate_result
      assert validated.valid == false
      assert validated.error == "Invalid signature"
    end
  end
end
