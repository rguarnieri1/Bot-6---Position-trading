using BotCripto.Models;

namespace BotCripto.Strategies;

// Position trading long-only su candele giornaliere:
//  1) trend primario rialzista: Close > EMA50 > EMA200 e EMA50 in salita
//  2) pullback: nelle ultime candele il minimo ha toccato la zona EMA20/EMA50 e la candela chiude di nuovo sopra EMA20
//  3) ripartenza: candela rialzista, RSI14 in recupero (>45, in crescita) e non ipercomprato
//  4) filtro di mercato: BTC sopra la sua EMA50
// Stop loss sotto il minimo dello swing recente (meno un buffer ATR); il target lo calcola il RiskManager (R:R configurato).
public class PositionTradingStrategy
{
    private const int FastEma = 20;
    private const int MidEma = 50;
    private const int SlowEma = 200;
    private const int BtcRegimeEmaPeriod = 50;
    private const int PullbackLookback = 5;      // candele entro cui deve essere avvenuto il pullback
    private const int SwingLookback = 10;        // candele per il minimo dello swing (stop)
    private const int AtrPeriod = 14;
    private const decimal AtrStopBuffer = 0.5m;  // buffer sotto lo swing, in ATR
    private const decimal RsiMin = 45m;
    private const decimal RsiMax = 70m;
    private const decimal MaxStopPercent = 0.15m; // stop più largo del 15% = setup scartato
    public const int MinCandles = SlowEma + 10;

    // Regime di mercato: true se BTC chiude sopra la sua EMA50, false se sotto, null se dati insufficienti.
    public static bool? IsBtcBullish(List<Candle> btcCandles)
    {
        var ema = TechnicalIndicators.CalculateEMA(btcCandles.Select(c => c.Close).ToList(), BtcRegimeEmaPeriod);
        if (ema.Count == 0)
            return null;
        return btcCandles.Last().Close > ema.Last();
    }

    public AnalysisResult Analyze(string symbol, List<Candle> candles, bool? btcBullish)
    {
        var result = new AnalysisResult
        {
            Symbol = symbol,
            StrategyName = "Position Trading (Trend EMA50/200 + Pullback)",
            IsSignal = false,
            Signal = "No Signal",
            AnalysisTime = DateTime.UtcNow
        };

        if (candles.Count < MinCandles)
        {
            result.Rejection = RejectionReason.InsufficientData;
            return result;
        }

        var closes = candles.Select(c => c.Close).ToList();
        var ema20 = TechnicalIndicators.CalculateEMA(closes, FastEma);
        var ema50 = TechnicalIndicators.CalculateEMA(closes, MidEma);
        var ema200 = TechnicalIndicators.CalculateEMA(closes, SlowEma);
        var rsi = TechnicalIndicators.CalculateRSI(closes);
        if (ema20.Count == 0 || ema50.Count < 6 || ema200.Count == 0 || rsi.Count < 2)
        {
            result.Rejection = RejectionReason.InsufficientData;
            return result;
        }

        var last = candles.Last();
        result.CurrentPrice = last.Close;

        // Le serie EMA sono allineate alla fine: l'indice i-esimo dalla fine corrisponde alla candela i-esima dalla fine
        decimal E20(int back) => ema20[ema20.Count - 1 - back];
        decimal E50(int back) => ema50[ema50.Count - 1 - back];

        var e20 = E20(0);
        var e50 = E50(0);
        var e200 = ema200.Last();
        result.Indicators["EMA20"] = e20;
        result.Indicators["EMA50"] = e50;
        result.Indicators["EMA200"] = e200;

        // 1) Trend primario
        bool trendUp = last.Close > e50 && e50 > e200 && e50 > E50(5);
        if (!trendUp)
        {
            result.Rejection = RejectionReason.TrendNotAligned;
            return result;
        }

        // 2) Pullback recente verso la zona EMA20/EMA50 e ripresa sopra EMA20
        bool pullback = false;
        for (int back = 1; back <= PullbackLookback; back++)
        {
            var c = candles[candles.Count - 1 - back];
            if (c.Low <= E20(back) && c.Low >= E50(back) * 0.97m)
            {
                pullback = true;
                break;
            }
        }
        if (!pullback || last.Close <= e20)
        {
            result.Rejection = RejectionReason.NoBreakout;
            return result;
        }

        // 3) Ripartenza: candela rialzista e RSI in recupero ma non ipercomprato
        var rsiNow = rsi.Last();
        var rsiPrev = rsi[rsi.Count - 2];
        result.Indicators["RSI"] = rsiNow;
        bool bullishCandle = last.Close > last.Open;
        if (!bullishCandle || rsiNow < RsiMin || rsiNow > RsiMax || rsiNow <= rsiPrev)
        {
            result.Rejection = RejectionReason.RsiExtreme;
            return result;
        }

        // 4) Regime BTC
        if (btcBullish != true)
        {
            result.Rejection = RejectionReason.AgainstBtcRegime;
            return result;
        }

        // Stop sotto lo swing low recente, con buffer ATR
        var atr = CalculateAtr(candles, AtrPeriod);
        var swingLow = candles.Skip(candles.Count - SwingLookback).Min(c => c.Low);
        var stop = swingLow - atr * AtrStopBuffer;
        if (stop <= 0 || stop >= last.Close || (last.Close - stop) / last.Close > MaxStopPercent)
        {
            result.Rejection = RejectionReason.StopLossError;
            return result;
        }

        result.IsSignal = true;
        result.Signal = "BUY";
        result.Indicators["StopLoss"] = stop;
        result.Indicators["ATR"] = atr;
        // Più forte = trend più marcato (distanza EMA50 da EMA200) e RSI più in alto nel range consentito
        result.Indicators["SignalStrength"] = (e50 - e200) / e200 * 100m + (rsiNow - RsiMin) / 10m;
        return result;
    }

    private static decimal CalculateAtr(List<Candle> candles, int period)
    {
        var trs = new List<decimal>();
        for (int i = candles.Count - period; i < candles.Count; i++)
        {
            var c = candles[i];
            var prevClose = candles[i - 1].Close;
            trs.Add(Math.Max(c.High - c.Low, Math.Max(Math.Abs(c.High - prevClose), Math.Abs(c.Low - prevClose))));
        }
        return trs.Average();
    }
}
