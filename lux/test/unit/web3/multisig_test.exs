defmodule Lux.Web3.MultisigTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Multisig.Approval

  describe "create_proposal/5" do
    test "creates a proposal with default proposer approval" do
      config = %{
        required: :multisig,
        signers: ["0xA", "0xB", "0xC"],
        threshold: 2
      }

      {:ok, proposal} =
        Approval.create_proposal(config, "0xA", "0xTarget", <<0x01>>, 1000000)

      assert proposal.proposer == "0xa"
      assert proposal.target == "0xTarget"
      assert proposal.value == 1000000
      assert proposal.executed == false
      assert Map.has_key?(proposal.approvals, "0xa")
    end

    test "rejects invalid configs" do
      bad_config = %{required: :multisig, signers: [], threshold: 1}

      assert {:error, reason} =
               Approval.create_proposal(bad_config, "0xA", "0xTarget", <<>>, 0)

      assert reason =~ "Invalid config"
    end

    test "rejects non-signer proposers" do
      config = %{required: :multisig, signers: ["0xA"], threshold: 1}

      assert {:error, reason} =
               Approval.create_proposal(config, "0xB", "0xTarget", <<>>, 0)

      assert reason =~ "not in signer list"
    end
  end

  describe "approve/3" do
    test "allows signers to approve" do
      config = %{required: :multisig, signers: ["0xA", "0xB"], threshold: 2}

      {:ok, proposal} = Approval.create_proposal(config, "0xA", "0xTarget", <<>>, 0)

      {:ok, approved} = Approval.approve(proposal, "0xB", "")
      assert approved.executed == true
      assert length(Approval.get_approvers(approved)) == 2
    end

    test "prevents double-approval" do
      config = %{required: :multisig, signers: ["0xA", "0xB"], threshold: 1}

      {:ok, proposal} = Approval.create_proposal(config, "0xA", "0xTarget", <<>>, 0)
      assert {:error, reason} = Approval.approve(proposal, "0xa", "")
      assert reason =~ "Already approved"
    end

    test "executed proposals cannot be re-approved" do
      config = %{required: :multisig, signers: ["0xA", "0xB"], threshold: 2}

      {:ok, proposal} = Approval.create_proposal(config, "0xA", "0xTarget", <<>>, 0)
      {:ok, executed} = Approval.approve(proposal, "0xB", "")

      assert {:error, reason} = Approval.approve(executed, "0xA", "")
      assert reason =~ "already executed"
    end

    test "non-signers cannot approve" do
      config = %{required: :multisig, signers: ["0xA"], threshold: 1}

      {:ok, proposal} = Approval.create_proposal(config, "0xA", "0xTarget", <<>>, 0)
      assert {:error, reason} = Approval.approve(proposal, "0xNobody", "")
      assert reason =~ "not a signer"
    end
  end

  describe "is_approved?/1" do
    test "returns true when threshold is met" do
      config = %{required: :multisig, signers: ["0xA", "0xB"], threshold: 1}

      {:ok, proposal} = Approval.create_proposal(config, "0xA", "0xTarget", <<>>, 0)
      assert Approval.is_approved?(proposal)
    end

    test "returns false when threshold not met" do
      config = %{required: :multisig, signers: ["0xA", "0xB", "0xC"], threshold: 2}

      {:ok, proposal} = Approval.create_proposal(config, "0xA", "0xTarget", <<>>, 0)
      refute Approval.is_approved?(proposal)
    end
  end
end
