"""
Telegram command parsing, argument coercion, validation, and routing engine.

Provides modular command handlers, subcommands, named flags and options,
type coercion, role-based permission checks, middleware execution hooks,
and dynamic documentation/help generation.
"""

from __future__ import annotations

import inspect
import re
import shlex
from dataclasses import dataclass, field
from typing import (
    Any,
    Callable,
    Coroutine,
    Dict,
    List,
    Optional,
    Set,
    Tuple,
    Type,
    Union,
)

from lux.telegram.types import (
    Message,
    ParsedCommand,
    PermissionLevel,
    User,
)


class CommandError(Exception):
    """Base exception for command parsing and routing errors."""
    pass


class CommandPermissionError(CommandError):
    """Raised when user does not meet required permission level."""
    pass


class CommandValidationError(CommandError):
    """Raised when command arguments fail type coercion or validation."""
    pass


@dataclass
class CommandContext:
    """Contextual metadata passed to command handlers during dispatch."""
    command: ParsedCommand
    message: Message
    user: Optional[User] = None
    user_permission: PermissionLevel = PermissionLevel.USER
    bot_username: Optional[str] = None
    extra_state: Dict[str, Any] = field(default_factory=dict)


@dataclass
class CommandOption:
    """Definition of a command option or flag."""
    name: str
    short_name: Optional[str] = None
    type: Type = str
    default: Any = None
    required: bool = False
    help: str = ""
    choices: Optional[List[Any]] = None
    regex: Optional[str] = None


@dataclass
class CommandDefinition:
    """Definition and metadata for a registered command."""
    name: str
    handler: Callable[..., Any]
    description: str = ""
    usage: str = ""
    aliases: List[str] = field(default_factory=list)
    subcommands: Dict[str, CommandDefinition] = field(default_factory=dict)
    options: Dict[str, CommandOption] = field(default_factory=dict)
    permission: PermissionLevel = PermissionLevel.USER
    is_hidden: bool = False
    parent: Optional[CommandDefinition] = None


class CommandParser:
    """Parser for Telegram bot commands, flags, and arguments."""

    # Regex for command line: /command[@bot_username] [args]
    COMMAND_PATTERN = re.compile(r"^/([a-zA-Z0-9_]{1,64})(?:@([a-zA-Z0-9_]{3,32}))?(?:\s+(.*))?$", re.DOTALL)

    @classmethod
    def is_command(cls, text: Optional[str]) -> bool:
        """Checks if text begins with a valid bot command."""
        if not text:
            return False
        return bool(cls.COMMAND_PATTERN.match(text.strip()))

    @classmethod
    def parse(cls, text: str, default_bot_username: Optional[str] = None) -> ParsedCommand:
        """Parses a raw message string into a structured ParsedCommand."""
        if not text:
            raise CommandValidationError("Empty command text")

        match = cls.COMMAND_PATTERN.match(text.strip())
        if not match:
            raise CommandValidationError(f"Invalid command format: {text[:30]}")

        cmd_name = match.group(1).lower()
        bot_username = match.group(2)
        raw_args = match.group(3) or ""

        # Parse arguments with shlex for quote handling
        args, named_args, flags = cls._parse_arguments(raw_args)

        # Check for subcommand (first positional argument if not a flag)
        subcommand = None
        if args and not args[0].startswith("-"):
            subcommand = args[0].lower()

        return ParsedCommand(
            name=cmd_name,
            raw_command=f"/{cmd_name}",
            bot_username=bot_username or default_bot_username,
            subcommand=subcommand,
            args=args,
            named_args=named_args,
            flags=flags,
            raw_args=raw_args.strip(),
        )

    @classmethod
    def _parse_arguments(cls, raw_args: str) -> Tuple[List[str], Dict[str, Any], Set[str]]:
        """Parses arguments into positional args, named flags, and boolean switches."""
        if not raw_args.strip():
            return [], {}, set()

        try:
            tokens = shlex.split(raw_args)
        except ValueError:
            # Fallback if quotes are unclosed
            tokens = raw_args.split()

        positional_args: List[str] = []
        named_args: Dict[str, Any] = {}
        flags: Set[str] = set()

        idx = 0
        while idx < len(tokens):
            token = tokens[idx]

            # Long flag with value: --key=value
            if token.startswith("--") and "=" in token:
                key, val = token[2:].split("=", 1)
                named_args[key] = val
                idx += 1
            # Long flag without =: --key val OR --switch
            elif token.startswith("--"):
                key = token[2:]
                if idx + 1 < len(tokens) and not tokens[idx + 1].startswith("-"):
                    named_args[key] = tokens[idx + 1]
                    idx += 2
                else:
                    flags.add(key)
                    named_args[key] = True
                    idx += 1
            # Short flag: -f or -f val
            elif token.startswith("-") and len(token) > 1 and not token[1:].isdigit():
                flag_str = token[1:]
                if len(flag_str) == 1:
                    if idx + 1 < len(tokens) and not tokens[idx + 1].startswith("-"):
                        named_args[flag_str] = tokens[idx + 1]
                        flags.add(flag_str)
                        idx += 2
                    else:
                        flags.add(flag_str)
                        named_args[flag_str] = True
                        idx += 1
                else:
                    # Combined short flags like -abc
                    for ch in flag_str:
                        flags.add(ch)
                        named_args[ch] = True
                    idx += 1
            else:
                positional_args.append(token)
                idx += 1

        return positional_args, named_args, flags

    @staticmethod
    def coerce(value: Any, target_type: Type, regex: Optional[str] = None) -> Any:
        """Coerces a string value to the specified type with optional regex validation."""
        if value is None:
            return None

        if target_type == bool:
            if isinstance(value, bool):
                return value
            val_lower = str(value).strip().lower()
            if val_lower in ("true", "1", "yes", "y", "on", "enable", "enabled"):
                return True
            if val_lower in ("false", "0", "no", "n", "off", "disable", "disabled"):
                return False
            raise CommandValidationError(f"Cannot coerce '{value}' to boolean")

        if target_type == int:
            try:
                # Handle hex or decimal
                str_val = str(value).strip()
                if str_val.startswith("0x") or str_val.startswith("0X"):
                    return int(str_val, 16)
                return int(str_val)
            except ValueError:
                raise CommandValidationError(f"Invalid integer value: '{value}'")

        if target_type == float:
            try:
                return float(str(value).strip())
            except ValueError:
                raise CommandValidationError(f"Invalid float value: '{value}'")

        if target_type == str:
            str_val = str(value)
            if regex:
                if not re.match(regex, str_val):
                    raise CommandValidationError(f"Value '{str_val}' does not match pattern '{regex}'")
            return str_val

        return value


class CommandRouter:
    """Production router for command dispatch, middleware execution, and documentation."""

    def __init__(self, bot_username: Optional[str] = None):
        self.bot_username = bot_username
        self.commands: Dict[str, CommandDefinition] = {}
        self.aliases: Dict[str, str] = {}
        self.pre_middleware: List[Callable[[CommandContext], Optional[CommandContext]]] = []
        self.post_middleware: List[Callable[[CommandContext, Any], Any]] = []
        self.error_handlers: List[Callable[[CommandContext, Exception], Any]] = []

    def register(
        self,
        name: str,
        handler: Callable[..., Any],
        description: str = "",
        usage: str = "",
        aliases: Optional[List[str]] = None,
        permission: PermissionLevel = PermissionLevel.USER,
        options: Optional[List[CommandOption]] = None,
        is_hidden: bool = False,
    ) -> CommandDefinition:
        """Registers a command definition into the router."""
        cmd_name = name.lower().lstrip("/")
        opt_dict = {opt.name: opt for opt in (options or [])}

        cmd_def = CommandDefinition(
            name=cmd_name,
            handler=handler,
            description=description,
            usage=usage or f"/{cmd_name}",
            aliases=aliases or [],
            options=opt_dict,
            permission=permission,
            is_hidden=is_hidden,
        )

        self.commands[cmd_name] = cmd_def

        if aliases:
            for alias in aliases:
                self.aliases[alias.lower().lstrip("/")] = cmd_name

        return cmd_def

    def command(
        self,
        name: str,
        description: str = "",
        usage: str = "",
        aliases: Optional[List[str]] = None,
        permission: PermissionLevel = PermissionLevel.USER,
        options: Optional[List[CommandOption]] = None,
        is_hidden: bool = False,
    ):
        """Decorator for registering command handlers."""
        def decorator(func: Callable[..., Any]):
            self.register(
                name=name,
                handler=func,
                description=description or (func.__doc__ or "").strip(),
                usage=usage,
                aliases=aliases,
                permission=permission,
                options=options,
                is_hidden=is_hidden,
            )
            return func
        return decorator

    def subcommand(
        self,
        parent_name: str,
        sub_name: str,
        description: str = "",
        usage: str = "",
        permission: Optional[PermissionLevel] = None,
    ):
        """Decorator for registering subcommands under an existing parent command."""
        parent_key = parent_name.lower().lstrip("/")

        def decorator(func: Callable[..., Any]):
            if parent_key not in self.commands:
                raise CommandError(f"Parent command '{parent_key}' not found for subcommand '{sub_name}'")

            parent_cmd = self.commands[parent_key]
            sub_key = sub_name.lower().lstrip("/")

            sub_def = CommandDefinition(
                name=sub_key,
                handler=func,
                description=description or (func.__doc__ or "").strip(),
                usage=usage or f"/{parent_key} {sub_key}",
                permission=permission or parent_cmd.permission,
                parent=parent_cmd,
            )
            parent_cmd.subcommands[sub_key] = sub_def
            return func

        return decorator

    def add_pre_middleware(self, middleware: Callable[[CommandContext], Optional[CommandContext]]) -> None:
        """Adds a hook executed before the command handler."""
        self.pre_middleware.append(middleware)

    def add_post_middleware(self, middleware: Callable[[CommandContext, Any], Any]) -> None:
        """Adds a hook executed after the command handler succeeds."""
        self.post_middleware.append(middleware)

    def add_error_handler(self, handler: Callable[[CommandContext, Exception], Any]) -> None:
        """Adds an error handler hook."""
        self.error_handlers.append(handler)

    def resolve_command(self, cmd_name: str) -> Optional[CommandDefinition]:
        """Finds command definition by primary name or registered alias."""
        clean = cmd_name.lower().lstrip("/")
        if clean in self.commands:
            return self.commands[clean]
        if clean in self.aliases:
            return self.commands.get(self.aliases[clean])
        return None

    def execute(self, context: CommandContext) -> Any:
        """Synchronously executes the command matching context."""
        return self._dispatch(context, is_async=False)

    async def execute_async(self, context: CommandContext) -> Any:
        """Asynchronously executes the command matching context."""
        return await self._dispatch(context, is_async=True)

    def _dispatch(self, context: CommandContext, is_async: bool = False) -> Any:
        """Internal dispatching logic handling permissions, options, subcommands, and middleware."""
        parsed = context.command

        # Target bot validation
        if parsed.bot_username and self.bot_username:
            if parsed.bot_username.lower() != self.bot_username.lower():
                return None  # Command addressed to another bot in the group

        cmd_def = self.resolve_command(parsed.name)
        if not cmd_def:
            raise CommandValidationError(f"Unknown command: /{parsed.name}")

        try:
            # Run pre-middleware
            current_ctx = context
            for mw in self.pre_middleware:
                res = mw(current_ctx)
                if res is not None:
                    current_ctx = res

            # Determine target handler (subcommand or main)
            target_cmd = cmd_def
            effective_args = list(parsed.args)

            if parsed.subcommand and parsed.subcommand in cmd_def.subcommands:
                target_cmd = cmd_def.subcommands[parsed.subcommand]
                effective_args = effective_args[1:]  # Shift out subcommand name

            # Permission check
            if current_ctx.user_permission.value < target_cmd.permission.value:
                raise CommandPermissionError(
                    f"Permission denied: required {target_cmd.permission.name}, user has {current_ctx.user_permission.name}"
                )

            # Option validation & coercion
            coerced_options = self._process_options(target_cmd, parsed.named_args)
            current_ctx.command.named_args = coerced_options

            # Execute handler
            handler = target_cmd.handler
            sig = inspect.signature(handler)
            has_varargs = any(p.kind == inspect.Parameter.VAR_POSITIONAL for p in sig.parameters.values())

            # Bind parameters
            call_args = [current_ctx]
            if len(sig.parameters) > 1 or has_varargs:
                call_args.extend(effective_args)

            if is_async:
                if inspect.iscoroutinefunction(handler):
                    result = handler(*call_args)
                else:
                    result = handler(*call_args)
                # If handler returns a coroutine in async mode, await it
                if inspect.iscoroutine(result):
                    return self._dispatch_async_result(current_ctx, result)
            else:
                result = handler(*call_args)

            # Run post-middleware
            for pmw in self.post_middleware:
                result = pmw(current_ctx, result)

            return result

        except Exception as exc:
            for eh in self.error_handlers:
                try:
                    return eh(context, exc)
                except Exception:
                    continue
            raise

    async def _dispatch_async_result(self, ctx: CommandContext, coro: Coroutine) -> Any:
        """Awaits coroutine and runs post-middleware."""
        result = await coro
        for pmw in self.post_middleware:
            result = pmw(ctx, result)
        return result

    def _process_options(self, cmd_def: CommandDefinition, raw_named_args: Dict[str, Any]) -> Dict[str, Any]:
        """Validates and coerces named options according to command definition."""
        coerced: Dict[str, Any] = {}

        # Fill defaults
        for opt_name, opt in cmd_def.options.items():
            val = raw_named_args.get(opt_name)
            if val is None and opt.short_name:
                val = raw_named_args.get(opt.short_name)

            if val is None:
                if opt.required:
                    raise CommandValidationError(f"Missing required option: --{opt_name}")
                coerced[opt_name] = opt.default
            else:
                coerced_val = CommandParser.coerce(val, opt.type, opt.regex)
                if opt.choices and coerced_val not in opt.choices:
                    raise CommandValidationError(
                        f"Invalid choice for --{opt_name}: '{coerced_val}'. Allowed: {opt.choices}"
                    )
                coerced[opt_name] = coerced_val

        # Pass through remaining unrecognized options
        for k, v in raw_named_args.items():
            if k not in coerced:
                coerced[k] = v

        return coerced

    def generate_help(self, user_permission: PermissionLevel = PermissionLevel.USER) -> str:
        """Generates dynamic documentation for all accessible commands."""
        lines = ["*Available Commands:*\n"]

        for name, cmd in sorted(self.commands.items()):
            if cmd.is_hidden or cmd.permission.value > user_permission.value:
                continue

            desc = cmd.description or "No description provided."
            lines.append(f"• `{cmd.usage}` — {desc}")

            if cmd.subcommands:
                for sub_name, sub in sorted(cmd.subcommands.items()):
                    if sub.permission.value <= user_permission.value:
                        sub_desc = sub.description or ""
                        lines.append(f"  └ `{sub.usage}` {sub_desc}")

        return "\n".join(lines)
