-- Tabelle del Bot 6 nel database "bot" (schema bot6), corrispondenti ai file di log/dati del bot:
--   bot6.bot6_trades  -> Data/trades.json (classe Trade in Models/Cryptocurrency.cs)
--   bot6.bot6_signals -> Logs/signals_yyyy-MM-dd.log (segnali della strategia Position Trading)
--   bot6.bot6_cycles  -> Logs/cycles_yyyy-MM-dd.log (report "Ciclo completato")
-- Stessa struttura delle tabelle bot1.bot1_* del Bot 1, con gli indicatori della strategia del Bot 6.
-- Lo script non modifica le tabelle già esistenti.
IF DB_ID(N'bot') IS NULL
    CREATE DATABASE [bot];
GO
USE [bot];
GO
IF SCHEMA_ID(N'bot6') IS NULL
    EXEC(N'CREATE SCHEMA [bot6]');
GO
IF OBJECT_ID(N'bot6.bot6_trades', N'U') IS NULL
BEGIN
    CREATE TABLE [bot6].[bot6_trades] (
        [Id]               nvarchar(36)    NOT NULL,
        [Symbol]           nvarchar(50)    NULL,
        [OpenTime]         datetime2       NOT NULL,
        [CloseTime]        datetime2       NULL,
        [EntryPrice]       decimal(38, 18) NOT NULL,
        [ExitPrice]        decimal(38, 18) NULL,
        [Strategy]         nvarchar(200)   NULL,
        [Status]           nvarchar(20)    NULL,
        [Profit]           decimal(38, 18) NULL,
        [ProfitPercentage] decimal(38, 18) NULL,
        [IsLong]           bit             NOT NULL,
        [StopLoss]         decimal(38, 18) NOT NULL,
        [TargetPrice]      decimal(38, 18) NOT NULL,
        [PositionSize]     decimal(38, 18) NOT NULL,
        [SignalCandleTime] datetime2       NULL,
        [ExitReason]       nvarchar(100)   NULL,
        [Bot]              nvarchar(50)    NOT NULL CONSTRAINT [DF_bot6_trades_Bot] DEFAULT (N'Bot 6'), -- bot che ha scritto la riga
        CONSTRAINT [PK_bot6_trades] PRIMARY KEY ([Id])
    );
    CREATE INDEX [IX_bot6_trades_Symbol_Status] ON [bot6].[bot6_trades] ([Symbol], [Status]);
    PRINT 'Tabella bot6.bot6_trades creata';
END
ELSE
    PRINT 'Tabella bot6.bot6_trades gia esistente: nessuna modifica';
GO
IF OBJECT_ID(N'bot6.bot6_signals', N'U') IS NULL
BEGIN
    CREATE TABLE [bot6].[bot6_signals] (
        [Id]                 bigint IDENTITY(1,1) NOT NULL,
        [Symbol]             nvarchar(50)    NOT NULL,
        [Strategy]           nvarchar(200)   NULL,   -- StrategyName, es. Position Trading (Trend EMA50/200 + Pullback)
        [Signal]             nvarchar(200)   NULL,   -- testo del segnale, es. BUY
        [IsLong]             bit             NOT NULL,
        [Timeframe]          nvarchar(10)    NULL,   -- es. 1d
        [SignalCandleTime]   datetime2       NOT NULL, -- inizio della candela chiusa che ha generato il segnale (UTC)
        [AnalysisTime]       datetime2       NOT NULL, -- momento dell'analisi (UTC), la data/ora della riga di log
        [Price]              decimal(38, 18) NOT NULL, -- CurrentPrice = chiusura della candela del segnale
        -- Indicatori della strategia (PositionTradingStrategy)
        [EMA20]              decimal(38, 18) NULL,
        [EMA50]              decimal(38, 18) NULL,
        [EMA200]             decimal(38, 18) NULL,
        [RSI]                decimal(38, 18) NULL,
        [ATR]                decimal(38, 18) NULL,
        [SignalStrength]     decimal(38, 18) NULL,
        [StopLoss]           decimal(38, 18) NULL,
        -- Esito del Risk Manager
        [Accepted]           bit             NOT NULL, -- 1 = trade aperto, 0 = scartato dal Risk Manager
        [RejectionReason]    nvarchar(100)   NULL,
        [Target]             decimal(38, 18) NULL,
        [PositionSize]       decimal(38, 18) NULL,
        [RiskRewardRatio]    decimal(38, 18) NULL,
        [ExpectedProfit]     decimal(38, 18) NULL,
        [TradeId]            nvarchar(36)    NULL,   -- bot6.bot6_trades.Id del trade aperto dal segnale
        [Bot]                nvarchar(50)    NOT NULL CONSTRAINT [DF_bot6_signals_Bot] DEFAULT (N'Bot 6'), -- bot che ha scritto la riga
        CONSTRAINT [PK_bot6_signals] PRIMARY KEY ([Id])
    );
    CREATE INDEX [IX_bot6_signals_Symbol_SignalCandleTime] ON [bot6].[bot6_signals] ([Symbol], [SignalCandleTime]);
    PRINT 'Tabella bot6.bot6_signals creata';
END
ELSE
    PRINT 'Tabella bot6.bot6_signals gia esistente: nessuna modifica';
GO
IF OBJECT_ID(N'bot6.bot6_cycles', N'U') IS NULL
BEGIN
    CREATE TABLE [bot6].[bot6_cycles] (
        [Id]               bigint IDENTITY(1,1) NOT NULL,
        [CycleNumber]      int             NOT NULL, -- "Ciclo #N" (riparte da 1 a ogni avvio del bot)
        [StartTime]        datetime2       NOT NULL, -- inizio del ciclo (UTC)
        [EndTime]          datetime2       NULL,     -- fine del ciclo (UTC)
        [Timeframe]        nvarchar(10)    NULL,     -- es. 1d
        [NewCandle]        bit             NOT NULL, -- 1 = candela appena chiusa, ricerca segnali eseguita
        [SignalCandleTime] datetime2       NULL,     -- inizio dell'ultima candela chiusa (UTC)
        [BtcRegime]        nvarchar(20)    NULL,     -- Rialzista / Ribassista / Sconosciuto (solo con ricerca segnali)
        [CryptosAnalyzed]  int             NULL,     -- criptovalute analizzate (solo con ricerca segnali)
        [TradesClosed]     int             NOT NULL, -- trade chiusi su stop/target
        [SignalsFound]     int             NOT NULL, -- segnali trovati (trade aperti)
        [SignalsFiltered]  int             NOT NULL, -- segnali filtrati dal Risk Manager
        [OpenTrades]       int             NOT NULL, -- trade aperti a fine ciclo
        [CapitalCommitted] decimal(38, 18) NOT NULL, -- capitale impegnato nei trade aperti (EUR)
        [RealizedPnl]      decimal(38, 18) NOT NULL, -- P&L realizzato cumulativo (EUR)
        [RejectionCounts]  nvarchar(max)   NULL,     -- motivi di scarto del ciclo in JSON
        [Error]            nvarchar(max)   NULL,     -- messaggio se il ciclo e terminato con errore
        [Bot]              nvarchar(50)    NOT NULL CONSTRAINT [DF_bot6_cycles_Bot] DEFAULT (N'Bot 6'), -- bot che ha scritto la riga
        CONSTRAINT [PK_bot6_cycles] PRIMARY KEY ([Id])
    );
    CREATE INDEX [IX_bot6_cycles_StartTime] ON [bot6].[bot6_cycles] ([StartTime]);
    PRINT 'Tabella bot6.bot6_cycles creata';
END
ELSE
    PRINT 'Tabella bot6.bot6_cycles gia esistente: nessuna modifica';
GO
