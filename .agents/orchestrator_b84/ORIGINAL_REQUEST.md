# Original User Request — Bounty #84 (Binance Exchange Integration)

## Initial Request — 2026-08-06T18:42:38-05:00

Implementación completa de la Integración de **Binance Exchange** en Elixir para el framework **Spectral-Finance/lux** (Bounty #84 - $750 USD). Incluye conexión a APIs REST y WebSockets, sistemas de trading para Spot y Futuros (con Prisms y Lenses nativos de Lux), seguimiento de portafolio y manejo estricto de límites de tasa (Rate Limiting).

Working directory: /home/Konor1743/Operacion Dolar/lux/lux
Integrity mode: development

## Requirements

### R1. Clientes REST API (Spot & Futures) y Autenticación
Implementar clientes HTTP seguros en Elixir (usando `Req` u otro cliente) para interactuar con la API REST de Binance. Debe soportar peticiones públicas y privadas autenticadas (HMAC-SHA256) tanto para el mercado Spot como para Futuros (USDⓈ-M).

### R2. WebSockets & Market Data Streaming
Desarrollar módulos (Lenses) para capturar flujos de datos del mercado en tiempo real a través de WebSockets (ej. `BinanceTickerPriceLens`, `BinanceExchangeInfoLens`), garantizando resiliencia y reconexión automática.

### R3. Sistemas de Trading (Prisms para Spot y Futuros)
Implementar abstracciones nativas de Lux (Prisms) para la gestión completa de operaciones:
- **Spot:** `BinanceSpotAccountPrism`, `BinanceSpotOrderPrism`, `BinanceSpotCancelOrderPrism`, `BinanceSpotOpenOrdersPrism`.
- **Futuros:** `BinanceFuturesAccountPrism`, `BinanceFuturesOrderPrism`, `BinanceFuturesPositionPrism`, `BinanceFuturesCancelOrderPrism`.

### R4. Manejo Estricto de Rate Limiting
Desarrollar middleware o interceptores que respeten rigurosamente los límites de velocidad de Binance (Weight, Raw Requests) interceptando códigos 429 y manejando cabeceras `Retry-After` para proteger a los agentes de baneos.

### R5. Suite de Pruebas Automatizadas ExUnit
Crear tests de integración exhaustivos para cada componente de Spot y Futuros utilizando mocks (simulaciones locales) para verificar la autenticación, flujos JSON y manejo de rate limits sin gastar criptomonavivas ni requerir claves API vivas en el CI.

## Acceptance Criteria

### Integridad del Código y Arquitectura
- [ ] El código compila al 100% sin errores ni advertencias (`mix compile --warnings-as-errors`).
- [ ] Se incluye documentación en línea (`@moduledoc`, `@doc`) para cada Prism y Lens creado con ejemplos claros de uso en Elixir.

### Verificación Funcional y Rate Limits
- [ ] Todas las pruebas de `mix test` deben pasar exitosamente simulando respuestas de la API de Binance.
- [ ] Se comprueba programáticamente mediante un test que las peticiones excedidas (429) activan correctamente la pausa/reintento según el límite de tasa sin fallar abruptamente.
- [ ] Existe un test unitario que verifica que la firma HMAC-SHA256 para endpoints privados se genera matemáticamente correcta según las especificaciones de Binance.
