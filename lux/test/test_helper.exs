ExUnit.start(exclude: [:skip, :integration, :unit])

# Configure Logger to be less verbose during tests
Logger.configure(level: :warning)

# Disable Telegram API logging during tests
alias Lux.Lenses.Telegram.TelegramAPIHandler
TelegramAPIHandler.disable_logging()

# Silence specific loggers for the Telegram API (keeping this as a backup)
:logger.add_primary_filter(
  :silence_telegram_api,
  {&:logger_filters.domain/2, {:stop, :equal, [:"Lux.Lenses.Telegram"]}}
)

defmodule UnitAPICase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Lux.LLM.OpenAI
  alias Lux.Lens.TelegramLens
  using do
    quote do
      @moduletag :unit
    end
  end

  setup do
    Application.put_env(:lux, :req_options, plug: {Req.Test, Lux.Lens})
    Application.put_env(:lux, OpenAI, plug: {Req.Test, OpenAI})
    Application.put_env(:lux, TelegramLens, plug: {Req.Test, TelegramLens})

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
