defmodule Lux.Prisms.Telegram.DeepLinkHandlerTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.DeepLinkHandler

  test "decode base64 payload" do
    payload = Base.url_encode64("ref_code-abc123", padding: false)
    {:ok, result} = DeepLinkHandler.handler(%{payload: payload}, nil)
    assert result.decoded == "ref_code-abc123"
    assert result.action == "ref"
    assert result.is_referral == true
    assert result.referral_code == "abc123"
  end

  test "plain text payload" do
    {:ok, result} = DeepLinkHandler.handler(%{payload: "welcome!!xyz"}, nil)
    assert result.decoded == "welcome!!xyz"
    assert result.action == "welcome!!xyz"
  end

  test "simple action payload" do
    {:ok, result} = DeepLinkHandler.handler(%{payload: "premium!!!"}, nil)
    assert result.action == "premium!!!"
    assert result.params == %{}
  end

  test "startgroup type" do
    {:ok, result} = DeepLinkHandler.handler(%{payload: "setup", type: "startgroup"}, nil)
    assert result.type == "startgroup"
    assert result.action == "setup"
  end

  test "referral detection" do
    encoded = Base.url_encode64("ref_code-xyz", padding: false)
    {:ok, result} = DeepLinkHandler.handler(%{payload: encoded}, nil)
    assert result.is_referral == true
    assert result.referral_code == "xyz"
  end

  test "non-referral" do
    {:ok, result} = DeepLinkHandler.handler(%{payload: "help!!!"}, nil)
    assert result.is_referral == false
    assert result.referral_code == nil
  end
end
