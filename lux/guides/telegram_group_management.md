# Telegram Group Management

`Lux.Integrations.Telegram.GroupManager` builds deterministic Telegram Bot API action plans for
group and channel administration. It does not execute network requests; a bot transport can review,
log, and dispatch the generated plans.

The manager covers:

- member management plans for restrict, ban, unban, promote, demote, and invite-link workflows;
- group and admin permission templates;
- content moderation and spam protection;
- group setting updates such as title, description, permissions, slow mode, and pins;
- channel post send/edit/pin plans;
- normalized admin audit logs and filtered audit summaries.

```elixir
{:ok, moderation} =
  Lux.Integrations.Telegram.GroupManager.moderation_action_plan(%{
    actor_id: "bot",
    message: %{
      chat_id: -100123,
      message_id: 42,
      user_id: 7,
      text: "FREE tokens http://spam.example @one @two @three @four @five @six"
    },
    rules: %{
      allow_links: false,
      mention_limit: 5,
      medium_action: :delete
    }
  })

moderation.moderation.requests
moderation.audit
```

Agents can use `Lux.Prisms.Telegram.Group.ManageGroup` to request the same workflows through a
single prism action.
