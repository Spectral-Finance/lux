defmodule Lux.Web3.Auth.MultiSigTest do
  @moduledoc """
  Tests for the MultiSig module covering request creation,
  signature collection, and threshold verification.
  """

  use UnitCase

  alias Lux.Web3.Auth.MultiSig

  @signer1_key Base.decode16!(
                 "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
                 case: :lower
               )
  @signer1_address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  @signer2_key Base.decode16!(
                 "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
                 case: :lower
               )
  @signer2_address "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"

  @signer3_address "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc"

  setup do
    table_name = :"multisig_#{:erlang.unique_integer([:positive])}"
    name = :"multisig_server_#{:erlang.unique_integer([:positive])}"

    {:ok, pid} =
      MultiSig.start_link(
        name: name,
        table_name: table_name
      )

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{server: name}
  end

  defp sign_message(message, private_key) do
    hash = Lux.Web3.Auth.SignatureVerifier.hash_personal_message(message)
    {:ok, {signature, recovery_id}} = ExSecp256k1.sign_compact(hash, private_key)
    Base.encode16(signature <> <<recovery_id + 27>>, case: :lower)
  end

  describe "create_request/2" do
    test "creates a valid multi-sig request", %{server: server} do
      assert {:ok, request} =
               MultiSig.create_request(
                 %{
                   message: "Approve action",
                   signers: [@signer1_address, @signer2_address, @signer3_address],
                   threshold: 2
                 },
                 server
               )

      assert request.message == "Approve action"
      assert length(request.signers) == 3
      assert request.threshold == 2
      assert request.signatures == %{}
      assert request.complete == false
      assert is_binary(request.id)
    end

    test "creates a 1-of-1 request", %{server: server} do
      assert {:ok, request} =
               MultiSig.create_request(
                 %{
                   message: "Single signer",
                   signers: [@signer1_address],
                   threshold: 1
                 },
                 server
               )

      assert request.threshold == 1
    end

    test "creates a request with custom TTL", %{server: server} do
      assert {:ok, request} =
               MultiSig.create_request(
                 %{
                   message: "Custom TTL",
                   signers: [@signer1_address, @signer2_address],
                   threshold: 1,
                   ttl: 7200
                 },
                 server
               )

      diff = DateTime.diff(request.expires_at, request.created_at)
      assert diff == 7200
    end

    test "rejects missing signers", %{server: server} do
      assert {:error, _} =
               MultiSig.create_request(
                 %{message: "Test", threshold: 1},
                 server
               )
    end

    test "rejects empty signers list", %{server: server} do
      assert {:error, _} =
               MultiSig.create_request(
                 %{message: "Test", signers: [], threshold: 1},
                 server
               )
    end

    test "rejects threshold greater than signers count", %{server: server} do
      assert {:error, _} =
               MultiSig.create_request(
                 %{
                   message: "Test",
                   signers: [@signer1_address],
                   threshold: 2
                 },
                 server
               )
    end

    test "rejects zero threshold", %{server: server} do
      assert {:error, _} =
               MultiSig.create_request(
                 %{
                   message: "Test",
                   signers: [@signer1_address],
                   threshold: 0
                 },
                 server
               )
    end

    test "rejects missing message", %{server: server} do
      assert {:error, _} =
               MultiSig.create_request(
                 %{
                   signers: [@signer1_address],
                   threshold: 1
                 },
                 server
               )
    end
  end

  describe "add_signature/4" do
    test "adds a valid signature", %{server: server} do
      {:ok, request} =
        MultiSig.create_request(
          %{
            message: "Sign this message",
            signers: [@signer1_address, @signer2_address],
            threshold: 2
          },
          server
        )

      sig = sign_message("Sign this message", @signer1_key)

      assert {:ok, result} =
               MultiSig.add_signature(request.id, @signer1_address, sig, server)

      assert result.signatures_count == 1
      assert result.threshold == 2
      assert result.complete == false
    end

    test "completes request when threshold reached", %{server: server} do
      {:ok, request} =
        MultiSig.create_request(
          %{
            message: "Two signatures needed",
            signers: [@signer1_address, @signer2_address],
            threshold: 2
          },
          server
        )

      sig1 = sign_message("Two signatures needed", @signer1_key)
      sig2 = sign_message("Two signatures needed", @signer2_key)

      {:ok, _} = MultiSig.add_signature(request.id, @signer1_address, sig1, server)
      {:ok, result} = MultiSig.add_signature(request.id, @signer2_address, sig2, server)

      assert result.complete == true
      assert result.signatures_count == 2
    end

    test "rejects duplicate signature from same signer", %{server: server} do
      {:ok, request} =
        MultiSig.create_request(
          %{
            message: "No duplicates",
            signers: [@signer1_address, @signer2_address],
            threshold: 2
          },
          server
        )

      sig = sign_message("No duplicates", @signer1_key)

      {:ok, _} = MultiSig.add_signature(request.id, @signer1_address, sig, server)

      assert {:error, "address has already signed"} =
               MultiSig.add_signature(request.id, @signer1_address, sig, server)
    end

    test "rejects unauthorized signer", %{server: server} do
      {:ok, request} =
        MultiSig.create_request(
          %{
            message: "Authorized only",
            signers: [@signer1_address],
            threshold: 1
          },
          server
        )

      sig = sign_message("Authorized only", @signer2_key)

      assert {:error, "address is not an authorized signer"} =
               MultiSig.add_signature(request.id, @signer2_address, sig, server)
    end

    test "rejects signature for non-existent request", %{server: server} do
      sig = sign_message("No request", @signer1_key)

      assert {:error, "request not found"} =
               MultiSig.add_signature("fake-id", @signer1_address, sig, server)
    end

    test "rejects adding to complete request", %{server: server} do
      {:ok, request} =
        MultiSig.create_request(
          %{
            message: "One of two",
            signers: [@signer1_address, @signer2_address],
            threshold: 1
          },
          server
        )

      sig1 = sign_message("One of two", @signer1_key)
      sig2 = sign_message("One of two", @signer2_key)

      {:ok, result} = MultiSig.add_signature(request.id, @signer1_address, sig1, server)
      assert result.complete == true

      assert {:error, "request is already complete"} =
               MultiSig.add_signature(request.id, @signer2_address, sig2, server)
    end

    test "rejects expired request", %{server: server} do
      {:ok, request} =
        MultiSig.create_request(
          %{
            message: "Expired",
            signers: [@signer1_address],
            threshold: 1,
            ttl: 0
          },
          server
        )

      Process.sleep(10)
      sig = sign_message("Expired", @signer1_key)

      assert {:error, "request has expired"} =
               MultiSig.add_signature(request.id, @signer1_address, sig, server)
    end
  end

  describe "get_request/2" do
    test "retrieves an existing request", %{server: server} do
      {:ok, created} =
        MultiSig.create_request(
          %{
            message: "Get me",
            signers: [@signer1_address],
            threshold: 1
          },
          server
        )

      assert {:ok, retrieved} = MultiSig.get_request(created.id, server)
      assert retrieved.id == created.id
      assert retrieved.message == "Get me"
    end

    test "returns :not_found for unknown request", %{server: server} do
      assert {:error, :not_found} = MultiSig.get_request("fake-id", server)
    end

    test "returns :expired for expired request", %{server: server} do
      {:ok, request} =
        MultiSig.create_request(
          %{
            message: "Will expire",
            signers: [@signer1_address],
            threshold: 1,
            ttl: 0
          },
          server
        )

      Process.sleep(10)

      assert {:error, :expired} = MultiSig.get_request(request.id, server)
    end
  end

  describe "cancel_request/2" do
    test "cancels an existing request", %{server: server} do
      {:ok, request} =
        MultiSig.create_request(
          %{
            message: "Cancel me",
            signers: [@signer1_address],
            threshold: 1
          },
          server
        )

      assert :ok = MultiSig.cancel_request(request.id, server)
      assert {:error, :not_found} = MultiSig.get_request(request.id, server)
    end
  end
end
