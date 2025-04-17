import Config

# ... existing code ...

config :lux, :api_keys,
  openai: System.get_env("OPENAI_API_KEY"),
  together: System.get_env("TOGETHER_API_KEY"),
  anthropic: System.get_env("ANTHROPIC_API_KEY"),
  mira: System.get_env("MIRA_API_KEY")

# ... existing code ... 
