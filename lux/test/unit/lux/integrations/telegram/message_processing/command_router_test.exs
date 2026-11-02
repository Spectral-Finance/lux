defmodule Lux.Integrations.Telegram.MessageProcessing.CommandRouterTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.MessageProcessing.CommandParser
  alias Lux.Integrations.Telegram.MessageProcessing.CommandRouter

  describe "CommandRouter" do
    test "routes command to registered handler" do
      router =
        CommandRouter.new()
        |> CommandRouter.register("ping", fn _cmd, _ctx -> {:ok, "pong"} end,
          description: "Replies with pong"
        )

      {:ok, cmd} = CommandParser.parse("/ping")
      assert {:ok, "pong"} = CommandRouter.dispatch(router, cmd, %{})
    end

    test "handles unknown command with fallback" do
      router =
        CommandRouter.new()
        |> CommandRouter.set_fallback(fn cmd, _ctx ->
          {:ok, "Unknown command: #{cmd.command}"}
        end)

      {:ok, cmd} = CommandParser.parse("/unknown")
      assert {:ok, "Unknown command: unknown"} = CommandRouter.dispatch(router, cmd, %{})
    end

    test "enforces chat type restrictions" do
      router =
        CommandRouter.new()
        |> CommandRouter.register("admin_panel", fn _cmd, _ctx -> {:ok, "panel"} end,
          chat_types: [:private]
        )

      {:ok, cmd} = CommandParser.parse("/admin_panel")

      # Rejected in supergroup
      assert {:error, {:chat_type_not_allowed, :supergroup}} =
               CommandRouter.dispatch(router, cmd, %{chat_type: :supergroup})

      # Allowed in private
      assert {:ok, "panel"} = CommandRouter.dispatch(router, cmd, %{chat_type: :private})
    end

    test "enforces admin permissions" do
      router =
        CommandRouter.new()
        |> CommandRouter.register("ban", fn _cmd, _ctx -> {:ok, "banned"} end,
          permissions: [:admin]
        )

      {:ok, cmd} = CommandParser.parse("/ban 12345")

      # Denied for normal user
      assert {:error, :permission_denied} =
               CommandRouter.dispatch(router, cmd, %{is_admin: false})

      # Allowed for admin
      assert {:ok, "banned"} =
               CommandRouter.dispatch(router, cmd, %{is_admin: true})
    end

    test "formats BotFather commands list" do
      router =
        CommandRouter.new()
        |> CommandRouter.register("start", fn _, _ -> {:ok, nil} end, description: "Start the bot")
        |> CommandRouter.register("balance", fn _, _ -> {:ok, nil} end, description: "Check wallet balance")
        |> CommandRouter.register("secret", fn _, _ -> {:ok, nil} end, description: "Internal", hidden: true)

      output = CommandRouter.format_botfather_commands(router)
      assert String.contains?(output, "balance - Check wallet balance")
      assert String.contains?(output, "start - Start the bot")
      refute String.contains?(output, "secret")
    end

    test "generates formatted help documentation" do
      router =
        CommandRouter.new()
        |> CommandRouter.register("help", fn _, _ -> {:ok, nil} end,
          description: "Show available commands",
          usage: "/help"
        )

      markdown_help = CommandRouter.generate_help_text(router, :markdown)
      assert String.contains?(markdown_help, "Available Commands")
      assert String.contains?(markdown_help, "*/help*")

      html_help = CommandRouter.generate_help_text(router, :html)
      assert String.contains?(html_help, "<b>/help</b>")
    end
  end
end
