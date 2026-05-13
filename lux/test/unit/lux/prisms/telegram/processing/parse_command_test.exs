defmodule Lux.Prisms.Telegram.Processing.ParseCommandTest do
  use UnitCase, async: true

  alias Lux.Prisms.Telegram.Processing.ParseCommand

  describe "handler/2" do
    test "parses command, bot username, tokens, params, and mentions" do
      assert {:ok, result} =
               ParseCommand.handler(
                 %{text: ~s(/deploy@LuxBot "main branch" --force env=prod @alice)},
                 %{name: "TestAgent"}
               )

      assert result.command == "deploy"
      assert result.bot_username == "LuxBot"
      assert result.arguments == ~s("main branch" --force env=prod @alice)
      assert result.tokens == ["main branch", "--force", "env=prod", "@alice"]
      assert result.params == %{"force" => true, "env" => "prod"}
      assert result.mentions == ["@alice"]
      assert result.deep_link_payload == nil
    end

    test "extracts start deep-link payload" do
      assert {:ok, result} = ParseCommand.handler(%{text: "/start campaign_42"}, nil)

      assert result.command == "start"
      assert result.tokens == ["campaign_42"]
      assert result.deep_link_payload == "campaign_42"
    end

    test "rejects non-command text" do
      assert {:error, "Text does not contain a Telegram command"} =
               ParseCommand.handler(%{text: "hello there"}, nil)
    end

    test "validates text" do
      assert {:error, "Missing or invalid text"} = ParseCommand.handler(%{}, nil)
    end
  end

  describe "schema validation" do
    test "declares input and output schemas" do
      prism = ParseCommand.view()

      assert prism.input_schema.required == ["text"]
      assert Map.has_key?(prism.input_schema.properties, :text)
      assert prism.output_schema.required == ["command", "arguments", "tokens", "params", "mentions"]
      assert Map.has_key?(prism.output_schema.properties, :deep_link_payload)
    end
  end
end
