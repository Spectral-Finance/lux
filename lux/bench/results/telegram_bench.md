# Telegram Integration Benchmark Results

- **Iterations**: 10000 per benchmark
- **Date**: 2026-08-25T01:46:27.297860Z
- **Host**: Linux / BEAM (Elixir 1.18.3)

| Benchmark | Operations / sec (IPS) | Mean Latency | Min Latency | p99 Latency | Total Time |
|:---|:---:|:---:|:---:|:---:|:---:|
| TelegramUpdate.new/1 (Message update) | 77,848 | 12.85 µs | 5 µs | 115 µs | 128.45 ms |
| TelegramUpdate.new/1 (Callback query) | 43,573 | 22.95 µs | 5 µs | 163 µs | 229.5 ms |
| TelegramUpdate.new/1 (Invalid payload rejection) | 149,100 | 6.71 µs | 4 µs | 46 µs | 67.07 ms |
| TelegramUpdate.chat_id/1 extraction | 921,658 | 1.08 µs | 0 µs | 2 µs | 10.85 ms |
| TelegramUpdate.text/1 extraction | 2,426,006 | 0.41 µs | 0 µs | 1 µs | 4.12 ms |
| TelegramUpdate.to_struct/1 conversion | 116,894 | 8.55 µs | 2 µs | 26 µs | 85.55 ms |
| TelegramUpdate.to_atom_keys/1 (Atom-safe) | 214,638 | 4.66 µs | 1 µs | 36 µs | 46.59 ms |
| WebhookPlug.call/2 (Valid signed request -> 200) | 6,666 | 150.0 µs | 20 µs | 1146 µs | 1500.03 ms |
| WebhookPlug.call/2 (Malformed JSON rejection -> 400) | 3,670 | 272.42 µs | 71 µs | 1061 µs | 2724.18 ms |
| WebhookPlug.call/2 (Unauthorized rejection -> 401) | 1,617 | 618.12 µs | 131 µs | 2717 µs | 6181.23 ms |
| Poller.poll_once/1 (Batch of 3 updates) | 3,621 | 276.13 µs | 74 µs | 1475 µs | 2761.32 ms |
