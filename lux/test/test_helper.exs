ExUnit.start(exclude: [:skip, :integration, :unit])

# Configure Logger to be less verbose during tests
Logger.configure(level: :warning)

# Silence specific loggers for the Telegram API
:logger.add_primary_filter(
  :silence_telegram_api,
  {&:logger_filters.domain/2, {:stop, :equal, [:"Lux.Lenses.Telegram"]}}
)

defmodule UnitAPICase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Lux.LLM.OpenAI
  alias Lux.Lens.TelegramLens
  alias Lux.Lenses.Etherscan
  alias Lux.LLM.Anthropic
  alias Lux.Integrations.Discord.Client, as: DiscordClient

  using do
    quote do
      @moduletag :unit
    end
  end

  setup do
    Application.put_env(:lux, :req_options, plug: {Req.Test, Lux.Lens})
    Application.put_env(:lux, OpenAI, plug: {Req.Test, OpenAI})
    Application.put_env(:lux, TelegramLens, plug: {Req.Test, TelegramLens})
    Application.put_env(:lux, Etherscan, plug: {Req.Test, Etherscan})
    Application.put_env(:lux, Anthropic, plug: {Req.Test, Anthropic})
    Application.put_env(:lux, DiscordClient, plug: {Req.Test, DiscordClientMock})
    :ok
  end
end

defmodule IntegrationCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :integration

    end
  end
end
