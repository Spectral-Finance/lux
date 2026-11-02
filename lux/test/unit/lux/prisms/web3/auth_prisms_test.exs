defmodule Lux.Prisms.Web3.AuthPrismsTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Web3.Auth.{
    CreateSIWEMessagePrism,
    VerifySignaturePrism,
    CreateSessionPrism,
    ValidateSessionPrism,
    CheckTokenGatePrism,
    AuthorizeActionPrism
  }

  @test_address "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5"

  describe "CreateSIWEMessagePrism" do
    test "generates standard SIWE message and nonce" do
      input = %{
        domain: "lux.ai",
        address: @test_address,
        uri: "https://lux.ai/login",
        statement: "Authenticate agent execution"
      }

      assert {:ok, result} = CreateSIWEMessagePrism.run(input)
      assert is_binary(result.nonce)
      assert String.length(result.nonce) >= 8
      assert String.contains?(result.message, "lux.ai wants you to sign in")
      assert String.contains?(result.message, @test_address)
    end
  end

  describe "VerifySignaturePrism" do
    test "verifies ERC-1271 contract signatures" do
      magic_sig = "0x" <> String.duplicate("00", 32) <> "1626ba7e" <> String.duplicate("00", 28)
      input = %{
        type: "erc1271",
        address: @test_address,
        hash: "0x" <> String.duplicate("ff", 32),
        signature: magic_sig
      }

      assert {:ok, result} = VerifySignaturePrism.run(input)
      assert result.valid == true
      assert result.signature_type == "erc1271"
    end
  end

  describe "CreateSessionPrism and ValidateSessionPrism" do
    test "creates and validates session bearer token" do
      input = %{
        address: @test_address,
        roles: ["trader"],
        chain_id: 1
      }

      assert {:ok, session_res} = CreateSessionPrism.run(input)
      assert is_binary(session_res.token)
      assert session_res.address == @test_address
      assert session_res.roles == ["trader"]

      assert {:ok, valid_res} = ValidateSessionPrism.run(%{token: session_res.token})
      assert valid_res.valid == true
      assert valid_res.address == @test_address
    end
  end

  describe "CheckTokenGatePrism" do
    test "evaluates token balance rules" do
      token = "0x1234567890123456789012345678901234567890"
      input = %{
        address: @test_address,
        operator: "all",
        rules: [
          %{type: "erc20", contract: token, min_balance: 100}
        ],
        balances: %{
          token => 200
        }
      }

      assert {:ok, result} = CheckTokenGatePrism.run(input)
      assert result.allowed == true
      assert result.matched_count == 1
    end
  end

  describe "AuthorizeActionPrism" do
    test "authorizes permitted actions based on role" do
      input = %{
        roles: ["trader"],
        required_permission: "execute_trades"
      }

      assert {:ok, res} = AuthorizeActionPrism.run(input)
      assert res.authorized == true

      denied_input = %{
        roles: ["trader"],
        required_permission: "administer_users"
      }

      assert {:ok, denied_res} = AuthorizeActionPrism.run(denied_input)
      assert denied_res.authorized == false
    end
  end
end
