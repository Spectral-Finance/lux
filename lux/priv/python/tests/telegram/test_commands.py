"""
Unit tests for CommandParser, CommandRouter, middleware, and permissions.
"""

from typing import Any
import pytest
from lux.telegram.commands import (
    CommandContext,
    CommandOption,
    CommandParser,
    CommandPermissionError,
    CommandRouter,
    CommandValidationError,
)
from lux.telegram.types import (
    Chat,
    ChatType,
    Message,
    PermissionLevel,
    User,
)


@pytest.fixture
def dummy_message():
    user = User(id=12345, first_name="Test", username="testuser")
    chat = Chat(id=999, type=ChatType.PRIVATE)
    return Message(message_id=1, chat=chat, from_user=user, date=1600000000, text="/start")


def test_command_parser_basic():
    parsed = CommandParser.parse("/trade buy ETH 1.5 --limit 3200 --slippage=0.5 -f")
    assert parsed.name == "trade"
    assert parsed.subcommand == "buy"
    assert parsed.args == ["buy", "ETH", "1.5"]
    assert parsed.named_args["limit"] == "3200"
    assert parsed.named_args["slippage"] == "0.5"
    assert "f" in parsed.flags


def test_command_parser_bot_username():
    parsed = CommandParser.parse("/help@LuxBot args here")
    assert parsed.name == "help"
    assert parsed.bot_username == "LuxBot"
    assert parsed.args == ["args", "here"]


def test_command_parser_quoted_args():
    parsed = CommandParser.parse('/post "This is a long title" --author="Vitalik B"')
    assert parsed.name == "post"
    assert parsed.args == ["This is a long title"]
    assert parsed.named_args["author"] == "Vitalik B"


def test_command_parser_coercion():
    assert CommandParser.coerce("123", int) == 123
    assert CommandParser.coerce("0x10", int) == 16
    assert CommandParser.coerce("42.5", float) == 42.5
    assert CommandParser.coerce("true", bool) is True
    assert CommandParser.coerce("0", bool) is False
    assert CommandParser.coerce("0x1234567890123456789012345678901234567890", str, regex=r"^0x[a-fA-F0-9]{40}$")

    with pytest.raises(CommandValidationError):
        CommandParser.coerce("not_an_int", int)

    with pytest.raises(CommandValidationError):
        CommandParser.coerce("invalid_addr", str, regex=r"^0x[a-fA-F0-9]{40}$")


def test_router_command_registration_and_dispatch(dummy_message):
    router = CommandRouter()

    @router.command("ping")
    def handle_ping(ctx: CommandContext):
        return "pong"

    parsed = CommandParser.parse("/ping")
    ctx = CommandContext(command=parsed, message=dummy_message)
    res = router.execute(ctx)
    assert res == "pong"


def test_router_subcommands(dummy_message):
    router = CommandRouter()

    @router.command("trade")
    def handle_trade(ctx: CommandContext):
        return "trade base"

    @router.subcommand("trade", "buy")
    def handle_buy(ctx: CommandContext, asset: str, amount: str):
        return f"Bought {amount} {asset}"

    parsed = CommandParser.parse("/trade buy ETH 2.0")
    ctx = CommandContext(command=parsed, message=dummy_message)
    res = router.execute(ctx)
    assert res == "Bought 2.0 ETH"


def test_router_options_and_choices(dummy_message):
    router = CommandRouter()

    @router.command(
        "order",
        options=[
            CommandOption(name="side", required=True, choices=["buy", "sell"]),
            CommandOption(name="amount", type=float, default=1.0),
        ],
    )
    def handle_order(ctx: CommandContext):
        opts = ctx.command.named_args
        return f"{opts['side']} of {opts['amount']}"

    # Valid call
    parsed = CommandParser.parse("/order --side buy --amount 5.5")
    ctx = CommandContext(command=parsed, message=dummy_message)
    res = router.execute(ctx)
    assert res == "buy of 5.5"

    # Missing required option
    with pytest.raises(CommandValidationError):
        p_bad = CommandParser.parse("/order --amount 5.5")
        ctx_bad = CommandContext(command=p_bad, message=dummy_message)
        router.execute(ctx_bad)

    # Invalid choice
    with pytest.raises(CommandValidationError):
        p_invalid = CommandParser.parse("/order --side hold")
        ctx_inv = CommandContext(command=p_invalid, message=dummy_message)
        router.execute(ctx_inv)


def test_router_permissions(dummy_message):
    router = CommandRouter()

    @router.command("admin_panel", permission=PermissionLevel.ADMIN)
    def handle_admin(ctx: CommandContext):
        return "admin_ok"

    parsed = CommandParser.parse("/admin_panel")

    # Regular user fails
    ctx_user = CommandContext(command=parsed, message=dummy_message, user_permission=PermissionLevel.USER)
    with pytest.raises(CommandPermissionError):
        router.execute(ctx_user)

    # Admin user passes
    ctx_admin = CommandContext(command=parsed, message=dummy_message, user_permission=PermissionLevel.ADMIN)
    res = router.execute(ctx_admin)
    assert res == "admin_ok"


def test_router_middleware(dummy_message):
    router = CommandRouter()
    log = []

    def pre_hook(ctx: CommandContext):
        log.append("pre")
        ctx.extra_state["added_by_middleware"] = True
        return ctx

    def post_hook(ctx: CommandContext, result: Any):
        log.append("post")
        return f"{result}_modified"

    router.add_pre_middleware(pre_hook)
    router.add_post_middleware(post_hook)

    @router.command("test")
    def handle_test(ctx: CommandContext):
        assert ctx.extra_state.get("added_by_middleware") is True
        return "output"

    parsed = CommandParser.parse("/test")
    ctx = CommandContext(command=parsed, message=dummy_message)
    res = router.execute(ctx)
    assert res == "output_modified"
    assert log == ["pre", "post"]


def test_generate_help():
    router = CommandRouter()
    router.register("start", lambda ctx: None, description="Starts the bot")
    router.register("admin_cmd", lambda ctx: None, description="Admin secret", permission=PermissionLevel.ADMIN)

    user_help = router.generate_help(PermissionLevel.USER)
    assert "/start" in user_help
    assert "admin_cmd" not in user_help

    admin_help = router.generate_help(PermissionLevel.ADMIN)
    assert "/start" in admin_help
    assert "/admin_cmd" in admin_help
