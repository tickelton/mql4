//+------------------------------------------------------------------+
//|                                                ttnFullTurtle.mq4 |
//|                                              tickelton@gmail.com |
//|                                     https://github.com/tickelton |
//+------------------------------------------------------------------+

/* MIT License

Copyright (c) 2017 tickelton@gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#include <stderror.mqh>
#include <stdlib.mqh>

#include <ttnCommon.mqh>

#property copyright "tickelton@gmail.com"
#property link      "https://github.com/tickelton"
#property version   "1.00"
#property strict

enum eStrategyType {
   StrategyTypeS1,
   StrategyTypeS2,
};

enum eLosingS1Trade {
   WasS1LoserYes,
   WasS1LoserNo,
   WasS1LoserNext,
};

enum eMAFilterDirection {
   DirMABuy,
   DirMASell,
   DirMABoth,
};

struct sTradeStatus {
   int openOffset;
   datetime lastTradeTime;
   eTradeDirection direction;
};

extern int MagicNumber_System1 = ttnMagicNumberTurtleSystem1;
extern int MagicNumber_System2 = ttnMagicNumberTurtleSystem2;
extern int PeriodS1Entry = 20;
extern int PeriodS1Exit = 10;
extern int PeriodS2Entry = 55;
extern int PeriodS2Exit = 20;
extern int PeriodATR = 14;
extern int SlowMAPeriod = 350;
extern int FastMAPeriod = 25;
extern bool SkipS1AfterWinningTrade = true;
extern bool UseMAFilter = true;
extern double EquityPctPerN = 1.0;
extern int UnitsPerTrade = 1;
extern int StopSizeInN = 2;
extern double PyramidingThresholdN = 0.5;
extern int MaxPyramidingTimeframe = 5;
extern int MaxUnitsPerCurrencyPair = 4;
extern int MaxUnitStronglyCorrelated = 5;
extern int MaxUnitMildlyCorrelated = 7;
extern int MaxUnitsPerDirection = 10;
extern eLogLevel LogLevel = LevelError;

const string eaName = "ttnFullTurtle";
datetime CurrentTimestamp;

int OnInit()
{

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{

   
}

void OnTick()
{
   CheckExit(StrategyTypeS2);
   CheckExit(StrategyTypeS1);
   CheckEntry(StrategyTypeS2);
   CheckEntry(StrategyTypeS1);
}

void CheckExit(eStrategyType strategyType)
{
   bool gotBullOrders = false;
   bool gotBearOrders = false;
   int magic;
   
   if(strategyType == StrategyTypeS1) {
      magic = MagicNumber_System1;
   } else if(strategyType == StrategyTypeS2) {
      magic = MagicNumber_System2;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("Error: CheckExit: Invalid strategy type: %d", strategyType);
      }
      return;
   }
   
   for(int pos=OrdersTotal()-1; pos>=0; pos--)
   {   
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      
      if(OrderMagicNumber() == magic &&
          OrderSymbol() == Symbol())
      {
         int type = OrderType();
         if(type == OP_BUY ||
             type == OP_BUYLIMIT ||
             type == OP_BUYSTOP)
         {
             gotBullOrders = true;
         } else if (type == OP_SELL ||
                     type == OP_SELLLIMIT ||
                     type == OP_SELLSTOP)
         {
            gotBearOrders = true;
         }
      }
   }
   
   if(gotBullOrders) {
      CheckBullExit(strategyType);
   }
   if(gotBearOrders) {
      CheckBearExit(strategyType);
   }
}
   
void CheckBullExit(eStrategyType strategyType)
{
   int period;
   int magic;
   if(strategyType == StrategyTypeS1) {
      period = PeriodS1Exit;
      magic = MagicNumber_System1;
   } else if(strategyType == StrategyTypeS2) {
      period = PeriodS2Exit;
      magic = MagicNumber_System2;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("Error: CheckBullExit: Invalid strategy type: %d", strategyType);
      }
      return;
   }
   
   double lowVal = iLow(Symbol(),Period(),iLowest(Symbol(),Period(),MODE_LOW,period,1));
   if(Bid < lowVal) {
      CloseBullPositions(magic);
   }
}

void CheckBearExit(eStrategyType strategyType)
{
   int period;
   int magic;
   if(strategyType == StrategyTypeS1) {
      period = PeriodS1Exit;
      magic = MagicNumber_System1;
   } else if(strategyType == StrategyTypeS2) {
      period = PeriodS2Exit;
      magic = MagicNumber_System2;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("Error: CheckBearExit: Invalid strategy type: %d", strategyType);
      }
      return;
   }
   
   double highVal = iHigh(Symbol(),Period(),iHighest(Symbol(),Period(),MODE_HIGH,period,1));
   if(Bid > highVal) {
      CloseBearPositions(magic);
   }
}

void CloseBullPositions(int magic)
{
   for(int pos=OrdersTotal()-1; pos>=0; pos--)
   {   
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      
      if(OrderMagicNumber() == magic &&
          OrderSymbol() == Symbol())
      {
         int type = OrderType();
         if(type == OP_BUY)
         {
            if(!OrderClose(OrderTicket(), OrderLots(), Bid, ttnDefaultSlippage, ttnClrBuyClose))
            {
               if(LogLevel >= LevelError)
               {
                  Print("Error: Cannot close order: " + ErrorDescription(GetLastError()));
               }
            }
         }
         else if(type == OP_BUYLIMIT ||
                  type == OP_BUYSTOP)
         {
            if(!OrderDelete(OrderTicket(), ttnClrDelete))
            {
               if(LogLevel >= LevelError)
               {
                  Print("Error: Cannot delete order: " + ErrorDescription(GetLastError()));
               }
            }
         }
      }
   }
}

void CloseBearPositions(int magic)
{
   for(int pos=OrdersTotal()-1; pos>=0; pos--)
   {   
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      
      if(OrderMagicNumber() == magic &&
          OrderSymbol() == Symbol())
      {
         int type = OrderType();
         if (type == OP_SELL)
         {
            if(!OrderClose(OrderTicket(), OrderLots(), Ask, ttnDefaultSlippage, ttnClrSellClose))
            {
               if(LogLevel >= LevelError)
               {
                  Print("Error: Cannot close order: " + ErrorDescription(GetLastError()));
               }
            }
         }
         else if(type == OP_SELLLIMIT ||
                  type == OP_SELLSTOP)
         {
            if(!OrderDelete(OrderTicket(), ttnClrDelete))
            {
               if(LogLevel >= LevelError)
               {
                  Print("Error: Cannot delete order: " + ErrorDescription(GetLastError()));
               }
            }
         }
      }
   }
}

void CheckEntry(eStrategyType strategyType)
{
   if(strategyType != StrategyTypeS1 && strategyType != StrategyTypeS2) {
      if(LogLevel >= LevelError) {
         PrintFormat("Error: CheckEntry: Invalid strategy type: %d", strategyType);
      }
      return;
   }
   
   sTradeStatus tradeStatus = CurrentlyTrading(strategyType);
   if(tradeStatus.openOffset > -1) {
      if(GotFreeVolume(tradeStatus)) {
         CheckPyramiding(strategyType, tradeStatus);
      }
   } else if(tradeStatus.openOffset == -1) {
      eTradeDirection tmpDir = EntrySignalGiven(strategyType);
      if(tmpDir != DIR_NONE) {
         tradeStatus.direction = tmpDir;
         if(GotFreeVolume(tradeStatus)) {
            if(EnterPosition(strategyType, tradeStatus) == -1) {
               if(LogLevel >= LevelError) {
                  Print("CheckEntry: Error opening position.");
               }
            }
         }
      }
   } else {
      if(LogLevel >= LevelError) {
         Print("CheckEntry: Unable to determine trading status.");
      }
   }
}

sTradeStatus CurrentlyTrading(eStrategyType strategyType)
{
   sTradeStatus tradeStatus;
   tradeStatus.openOffset = -2;
   tradeStatus.direction = DIR_NONE;
   int magic;
   
   if(strategyType == StrategyTypeS1) {
      magic = MagicNumber_System1;
   } else if(strategyType == StrategyTypeS2) {
      magic = MagicNumber_System2;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("Error: CurrentlyTrading: Invalid strategy type: %d", strategyType);
      }
      return tradeStatus;
   }

   
   bool gotBullOrders = false;
   bool gotBearOrders = false;
   
   for(int pos=OrdersTotal()-1; pos>=0; pos--)
   {   
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      
      if(OrderMagicNumber() == magic &&
          OrderSymbol() == Symbol())
      {
         int type = OrderType();
         if(type == OP_BUY ||
             type == OP_BUYLIMIT ||
             type == OP_BUYSTOP)
         {
             gotBullOrders = true;
         } else if (type == OP_SELL ||
                     type == OP_SELLLIMIT ||
                     type == OP_SELLSTOP)
         {
            gotBearOrders = true;
         }
      }
   }

   if(!gotBearOrders && !gotBullOrders) {
      tradeStatus.openOffset = -1;
   } else if(gotBearOrders && gotBullOrders) {
      if(LogLevel >= LevelCritical) {
         PrintFormat(
            "Critical: CurrentlyTrading(%d): Open orders in both directions!",
            strategyType
         );
      }
      tradeStatus.openOffset = -2;
   } else if(gotBearOrders && !gotBullOrders) {
      tradeStatus.direction = DIR_SELL;
      GetOrderStatus(strategyType, tradeStatus);
   } else if(!gotBearOrders && gotBullOrders) {
      tradeStatus.direction = DIR_BUY;
      GetOrderStatus(strategyType, tradeStatus);
   } else {
      if(LogLevel >= LevelCritical) {
         PrintFormat(
            "Critical: CurrentlyTrading(%d): This should not happen!",
            strategyType
         );
      }
      tradeStatus.openOffset = -2;
   }

   return tradeStatus;
}

void GetOrderStatus(eStrategyType strategyType, sTradeStatus &status)
{
   int magic;
   if(strategyType == StrategyTypeS1) {
      magic = MagicNumber_System1;
   } else if(strategyType == StrategyTypeS2) {
      magic = MagicNumber_System2;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("Error: GetOpenOffset: Invalid strategy type: %d", strategyType);
      }
      status.openOffset = -2;
      return;
   }
   
   if(status.direction != DIR_BUY && status.direction != DIR_SELL) {
      if(LogLevel >= LevelError) {
         PrintFormat("Error: GetOpenOffset: Invalid direction: %d", status.direction);
      }
      status.openOffset = -2;
      return;
   }
   
   datetime openTime = D'01.01.1970';
   datetime lastTradeTime = D'01.01.1970';
   for(int pos=OrdersTotal()-1; pos>=0; pos--)
   {   
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      
      if(OrderMagicNumber() == magic &&
          OrderSymbol() == Symbol())
      {
         int type = OrderType();
         if(type == OP_BUY ||
             type == OP_BUYLIMIT ||
             type == OP_BUYSTOP)
         {
            if(status.direction == DIR_SELL) {
               if(LogLevel >= LevelCritical) {
                  PrintFormat(
                     "Critical: GetOpenOffset(%d): Looking for Sell oders but found Buy order!"
                  );
               }
               status.openOffset = -2;
               return;
            }
            if(openTime == D'01.01.1970') {
               openTime = OrderOpenTime();               
            } else {
               datetime tmpTime = OrderOpenTime();
               if(tmpTime < openTime) {
                  openTime = tmpTime;
               }
            }
            if(lastTradeTime == D'01.01.1970') {
               lastTradeTime = OrderOpenTime();               
            } else {
               datetime tmpTime = OrderOpenTime();
               if(tmpTime > lastTradeTime) {
                  lastTradeTime = tmpTime;
               }
            }
         } else if (type == OP_SELL ||
                     type == OP_SELLLIMIT ||
                     type == OP_SELLSTOP)
         {
            if(status.direction == DIR_BUY) {
               if(LogLevel >= LevelCritical) {
                  PrintFormat(
                     "Critical: GetOpenOffset(%d): Looking for Buy oders but found Sell order!"
                  );
               }
               status.openOffset = -2;
               return;
            }
            if(openTime == D'01.01.1970') {
               openTime = OrderOpenTime();               
            } else {
               datetime tmpTime = OrderOpenTime();
               if(tmpTime < openTime) {
                  openTime = tmpTime;
               }
            }
            if(lastTradeTime == D'01.01.1970') {
               lastTradeTime = OrderOpenTime();               
            } else {
               datetime tmpTime = OrderOpenTime();
               if(tmpTime > lastTradeTime) {
                  lastTradeTime = tmpTime;
               }
            }
         }
      }
   }

   if(openTime != D'01.01.1970' &&
       lastTradeTime != D'01.01.1970') {
      status.lastTradeTime = lastTradeTime;
      status.openOffset = GetPeriodOffset(openTime);
   } else {
      status.openOffset = -2;
   }
   
   return;
}

int GetPeriodOffset(datetime openTime)
{
   datetime curTime = TimeCurrent();
   int timeDiff = (int)(curTime - openTime);
   
   if(timeDiff < 0) {
      if(LogLevel >= LevelError) {
         PrintFormat("Error: GetPeriodOffset: Negative timeDiff: %d", timeDiff);
      }
      return -2;
   }
   
   int tfCurrent = Period();
   if(tfCurrent == PERIOD_M1) {
      return timeDiff / 60;
   } else if(tfCurrent == PERIOD_M5) {
      return timeDiff / 300;
   } else if(tfCurrent == PERIOD_M15) {
      return timeDiff / 900;
   } else if(tfCurrent == PERIOD_M30) {
      return timeDiff / 1800;
   } else if(tfCurrent == PERIOD_H1) {
      return timeDiff / 3600;
   } else if(tfCurrent == PERIOD_H4) {
      return timeDiff / 14400;
   } else if(tfCurrent == PERIOD_D1) {
      return timeDiff / 86400;
   } else {
      PrintFormat("Timeframe %d not supported", tfCurrent);
      return -2;
   }
   
   return -2;
}

bool GotFreeVolume(sTradeStatus &tradeStatus)
{
   double equityPerN = AccountBalance() *(EquityPctPerN / 100.0);
   
   double equityPerTrade = equityPerN * UnitsPerTrade;
   
   double equityPair = 0;
   double equityMildCorrelation = 0;
   double equityStrongCorrelation = 0;
   double equityDirection = 0;
   int unitsPair = 0;
   int unitsMildCorrelation = 0;
   int unitsStrongCorrelation = 0;
   int unitsDirection = 0;
   
   for(int pos=OrdersTotal()-1; pos>=0; pos--)
   {
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      
      double tmpRisk = 0;
      double tickValue = MarketInfo(Symbol(),MODE_TICKVALUE);
      int orderMagic = OrderMagicNumber();
  
      int type = OrderType();
      if(type == OP_BUY)
      {
         tmpRisk = ((OrderOpenPrice() - OrderStopLoss()) * OrderLots() * tickValue) / Point;
         if(tradeStatus.direction == DIR_BUY) {
            equityDirection += tmpRisk;
            if(orderMagic == MagicNumber_System1 ||
                orderMagic == MagicNumber_System2) {
               unitsDirection++;   
            }
         }
      } else if (type == OP_SELL)
      {
         tmpRisk = ((OrderStopLoss() - OrderOpenPrice()) * OrderLots() * tickValue) / Point;
         if(tradeStatus.direction == DIR_SELL) {
            equityDirection += tmpRisk;
            if(orderMagic == MagicNumber_System1 ||
                orderMagic == MagicNumber_System2) {
               unitsDirection++;   
            }
         }
      }
      
      if(!StringCompare(Symbol(), OrderSymbol())) {
         equityPair += tmpRisk;
         if(orderMagic == MagicNumber_System1 ||
             orderMagic == MagicNumber_System2) {
            unitsPair++;   
         }
      }
      if(IsCorrelated(Symbol(), OrderSymbol(), CORRELATION_MILD)) {
         equityMildCorrelation += tmpRisk;
         if(orderMagic == MagicNumber_System1 ||
             orderMagic == MagicNumber_System2) {
            unitsMildCorrelation++;   
         }
      }
      if(IsCorrelated(Symbol(), OrderSymbol(), CORRELATION_STRONG)) {
         equityStrongCorrelation += tmpRisk;
         if(orderMagic == MagicNumber_System1 ||
             orderMagic == MagicNumber_System2) {
            unitsStrongCorrelation++;   
         }
      }
      
   }

   if(unitsPair >= MaxUnitsPerCurrencyPair) {
      return false;
   }
   if(unitsMildCorrelation >= MaxUnitMildlyCorrelated) {
      return false;
   }
   if(unitsStrongCorrelation >= MaxUnitStronglyCorrelated) {
      return false;
   }
   if(unitsDirection >= MaxUnitsPerDirection) {
      return false;
   }
   if(equityPair + equityPerTrade > MaxUnitsPerCurrencyPair * equityPerTrade) {
      return false;
   }
   if(equityMildCorrelation + equityPerTrade > MaxUnitMildlyCorrelated * equityPerTrade) {
      return false;
   }
   if(equityStrongCorrelation + equityPerTrade > MaxUnitStronglyCorrelated * equityPerTrade) {
      return false;
   }
   if(equityDirection + equityPerTrade > MaxUnitsPerDirection * equityPerTrade) {
      return false;
   }
   
   return true;
}

bool IsCorrelated(string curSymbol, string orderSymbol, eCorrelationType type)
{
   for(int i=0; i<N_CURRENCY_PAIRS; i++) {
      if(!StringCompare(CorrelationTable[i].name, curSymbol, false)) {
         if(type == CORRELATION_MILD) {
            for(int j=0; j<N_CORRELATION_PAIRS; j++) {
               if(!StringCompare(orderSymbol, CorrelationTable[i].moderateCorrelation[j])) {
                  return true;
               }
            }
         } else if(type == CORRELATION_STRONG) {
            for(int j=0; j<N_CORRELATION_PAIRS; j++) {
               if(!StringCompare(orderSymbol, CorrelationTable[i].strongCorrelation[j])) {
                  return true;
               }
            }
         }
      }
   }

   return false;
}

eTradeDirection EntrySignalGiven(eStrategyType strategyType)
{
   int period;
   if(strategyType == StrategyTypeS1) {
      period = PeriodS1Entry;
   } else if(strategyType == StrategyTypeS2) {
      period = PeriodS2Entry;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("Error: EntrySignalGiven: Invalid strategy type: %d", strategyType);
      }
      return DIR_NONE;
   }
   
   int maDirection = DirMABoth;
   if(UseMAFilter) {
      if(Bars < SlowMAPeriod) {
         return DIR_NONE;
      }
      double slowMA = iMA(NULL, 0, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
      double fastMA = iMA(NULL, 0, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
      if(slowMA > fastMA) {
         maDirection = DirMASell;
      } else if(slowMA < fastMA) {
         maDirection = DirMABuy;
      } else {
         return DIR_NONE;
      }
   }
   
   if(maDirection == DirMABuy || maDirection == DirMABoth) {
      double maxVal = iHigh(Symbol(),Period(),iHighest(Symbol(),Period(),MODE_HIGH,period,1));
      if(Close[0] > maxVal) {
         if(strategyType == StrategyTypeS1 && SkipS1AfterWinningTrade) {
            return PreviousS1TradeWasLosing(DIR_BUY, 0);
         } else {
            return DIR_BUY;
         }
      }
   }

   if(maDirection == DirMASell || maDirection == DirMABoth) {
      double maxVal = iLow(Symbol(),Period(),iLowest(Symbol(),Period(),MODE_LOW,period,1));
      if(Close[0] < maxVal) {
         if(strategyType == StrategyTypeS1 && SkipS1AfterWinningTrade) {
            return PreviousS1TradeWasLosing(DIR_SELL, 0);
         } else {
            return DIR_SELL;
         }
      }
   }
   
   return DIR_NONE;
}

eTradeDirection PreviousS1TradeWasLosing(eTradeDirection direction, int offset)
{
   for(int i=offset; i<Bars; i++) {
      if(direction == DIR_BUY) {
         if(High[i] > iHigh(Symbol(),Period(),iHighest(Symbol(),Period(),MODE_HIGH,PeriodS1Entry,i+1))) {
            for(int j=i+1; j<Bars; j++) {
               if(High[j] <= iHigh(Symbol(),Period(),iHighest(Symbol(),Period(),MODE_HIGH,PeriodS1Entry,j+1))) {
                  eLosingS1Trade tradeState = CheckS1Loser(direction, j-1);
                  if(tradeState == WasS1LoserYes) {
                     return direction;
                  } else if(tradeState == WasS1LoserNo) {
                     return DIR_NONE;
                  } else if(tradeState == WasS1LoserNext) {
                     return PreviousS1TradeWasLosing(direction, j);
                  } else {
                     return DIR_NONE;
                  }
               }
            }
         }
      } else if(direction == DIR_SELL) {
         if(Low[i] < iLow(Symbol(),Period(),iLowest(Symbol(),Period(),MODE_LOW,PeriodS1Entry,i+1))) {
            for(int j=i+1; j<Bars; j++) {
               if(Low[i] >= iLow(Symbol(),Period(),iLowest(Symbol(),Period(),MODE_LOW,PeriodS1Entry,j+1))) {
                  eLosingS1Trade tradeState = CheckS1Loser(direction, j-1);
                  if(tradeState == WasS1LoserYes) {
                     return direction;
                  } else if(tradeState == WasS1LoserNo) {
                     return DIR_NONE;
                  } else if(tradeState == WasS1LoserNext) {
                     return PreviousS1TradeWasLosing(direction, j);
                  } else {
                     return DIR_NONE;
                  }
               }
            }
         }
      } else {
         if(LogLevel >= LevelError) {
            PrintFormat(
               "PreviousS1TradeWasLosing error: Invalid direction: %d",
               direction
            );
         }
         return DIR_NONE;
      }   
   }
   
   return DIR_NONE;
}

eLosingS1Trade CheckS1Loser(eTradeDirection direction, int offset)
{
   int lastPeriod = 1;
   bool foundExit = false;
   if(direction == DIR_BUY) {
      double openPrice = iHigh(Symbol(),Period(),iHighest(Symbol(),Period(),MODE_HIGH,PeriodS1Entry,offset));
      
      double curATR = iATR(NULL, 0, PeriodATR, offset+1);
      if(curATR == 0.0) {
         if(LogLevel >= LevelError) {
            PrintFormat("CheckS1Loser error: ATR=%f", curATR);
         }
         return WasS1LoserNo;
      }
      double stopLoss = openPrice - StopSizeInN * curATR;
      
      for(int i=offset-1; i>0; i++) {
         if(Low[i] < iLow(Symbol(),Period(),iLowest(Symbol(),Period(),MODE_LOW,PeriodS1Exit,i+1))) {
            if(Low[i] < openPrice) {
               return WasS1LoserYes;
            } else {
               foundExit = true;
               lastPeriod = i;
               break;
            }
         }
      }
      for(int i=offset; i>=lastPeriod; i++) {
         if(Low[i] < stopLoss) {
            if(i == offset) {
               if(Close[i] > Open[i]) {
                  continue;
               } else {
                  return WasS1LoserYes;
               }
            } else {
               return WasS1LoserYes;
            }
         }
      }
      if(!foundExit) {
         return WasS1LoserNext;
      } else {
         return WasS1LoserNo;
      }
   } else if(direction == DIR_SELL) {
      double openPrice = iLow(Symbol(),Period(),iLowest(Symbol(),Period(),MODE_LOW,PeriodS1Entry,offset));
      
      double curATR = iATR(NULL, 0, PeriodATR, offset+1);
      if(curATR == 0.0) {
         if(LogLevel >= LevelError) {
            PrintFormat("CheckS1Loser error: ATR=%f", curATR);
         }
         return WasS1LoserNo;
      }
      double stopLoss = openPrice + StopSizeInN * curATR;
      
      for(int i=offset-1; i>0; i++) {
         if(High[i] > iHigh(Symbol(),Period(),iHighest(Symbol(),Period(),MODE_HIGH,PeriodS1Exit,i+1))) {
            if(High[i] > openPrice) {
               return WasS1LoserYes;
            } else {
               foundExit = true;
               lastPeriod = i;
               break;
            }
         }
      }
      for(int i=offset; i>=lastPeriod; i++) {
         if(High[i] > stopLoss) {
            if(i == offset) {
               if(Close[i] < Open[i]) {
                  continue;
               } else {
                  return WasS1LoserYes;
               }
            } else {
               return WasS1LoserYes;
            }
         }
      }
      if(!foundExit) {
         return WasS1LoserNext;
      } else {
         return WasS1LoserNo;
      }
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat(
            "CheckS1Loser error: Invalid direction: %d",
            direction
         );
      }
      return WasS1LoserNo;
   }

   return WasS1LoserNo;
}

void CheckPyramiding(eStrategyType strategyType, sTradeStatus &status)
{
   if(PyramidingSignalGiven(strategyType, status)) {
      int ticketNr = EnterPosition(strategyType, status);
      if(ticketNr > -1) {
         MoveStops(strategyType, status, ticketNr);
      }
   }
}

void MoveStops(eStrategyType strategyType, sTradeStatus &status, int ticketNr)
{
   int magic;
   if(strategyType == StrategyTypeS1) {
      magic = MagicNumber_System1;
   } else if(strategyType == StrategyTypeS2) {
      magic = MagicNumber_System2;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("MoveStops error: Invalid strategy type: %d", strategyType);
      }
      return;
   }
   
   if(status.direction != DIR_BUY && status.direction != DIR_SELL) {
      if(LogLevel >= LevelError) {
         PrintFormat("MoveStops error: Invalid direction: %d", status.direction);
      }
      return;
   }
   
   int periodOffset;
   if(status.openOffset == -2 ) {
      if(LogLevel >= LevelError) {
         Print("MoveStops error: openOffset=-2"); 
      }
      return;
   } else if(status.openOffset < 1) {
      periodOffset = 1;
   } else {
      periodOffset = status.openOffset;
   }
   
   double orderATR = iATR(NULL, 0, PeriodATR, periodOffset);
   if(orderATR == 0.0) {
      if(LogLevel >= LevelError) {
         PrintFormat("MoveStops error: ATR=%f", orderATR); 
      }
      return;
   }
   
   for(int pos=OrdersTotal()-1; pos>=0; pos--)
   {   
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      
      if(OrderMagicNumber() == magic &&
          OrderSymbol() == Symbol() &&
          OrderTicket() != ticketNr)
      { 
         double oldStopLevel = OrderStopLoss();
         if(oldStopLevel == 0) {
            if(LogLevel >= LevelCritical) {
               PrintFormat(
                  "MoveStops error: Order does not have SL!"
               );
            }    
            continue; 
         }
            
         int type = OrderType();
         if(type == OP_BUY ||
             type == OP_BUYLIMIT ||
             type == OP_BUYSTOP)
         {
            if(status.direction == DIR_SELL) {
               if(LogLevel >= LevelCritical) {
                  PrintFormat(
                     "Critical: MoveStops: Looking for Sell oders but found Buy order!"
                  );
               }               
               return;
            }           
            
            double newStopLevel = oldStopLevel + PyramidingThresholdN * orderATR;
            if(!OrderModify(
                  OrderTicket(),
                  OrderOpenPrice(),
                  NormalizeDouble(newStopLevel, Digits),
                  OrderTakeProfit(),
                  0,
                  clrYellow)
             ) {
               if(LogLevel >= LevelError) {
                  Print("MoveStops warning: error trailing SL ", ErrorDescription(GetLastError()));
                  continue;
               }
            }            
         } else if (type == OP_SELL ||
                     type == OP_SELLLIMIT ||
                     type == OP_SELLSTOP)
         {
            if(status.direction == DIR_BUY) {
               if(LogLevel >= LevelCritical) {
                  PrintFormat(
                     "Critical: MoveStops: Looking for Buy oders but found Sell order!"
                  );
               }               
               return;
            }
            
            double newStopLevel = oldStopLevel - PyramidingThresholdN * orderATR;
            if(!OrderModify(
                  OrderTicket(),
                  OrderOpenPrice(),
                  NormalizeDouble(newStopLevel, Digits),
                  OrderTakeProfit(),
                  0,
                  clrYellow)
             ) {
               if(LogLevel >= LevelError) {
                  Print("MoveStops warning: error trailing SL ", ErrorDescription(GetLastError()));
                  continue;
               }
            }            
         }
      }
   }
}

bool PyramidingSignalGiven(eStrategyType strategyType, sTradeStatus &status)
{
   double lastPrice = GetLastPrice(strategyType, status);
   if(lastPrice < 0) {
      if(LogLevel >= LevelError) {
         Print("PyramidingSignalGiven error: lastPrice=%f",
            lastPrice); 
      }
      return false;
   }
   
   int periodOffset;
   if(status.openOffset == -2 ) {
      if(LogLevel >= LevelError) {
         Print("PyramidingSignalGiven error: openOffset=-2"); 
      }
      return false;
   } else if(status.openOffset < 1) {
      periodOffset = 1;
   } else {
      periodOffset = status.openOffset;
   }
   
   if(periodOffset > MaxPyramidingTimeframe) {
      return false;
   }
   
   double curATR = iATR(NULL, 0, PeriodATR, periodOffset);
   if(curATR == 0.0) {
      if(LogLevel >= LevelError) {
         PrintFormat("PyramidingSignalGiven error: ATR=%f", curATR); 
      }
      return false;
   }

   if(status.direction == DIR_BUY) {
      if(Ask >= lastPrice + (curATR * PyramidingThresholdN)) {
         return true;
      }
   } else if(status.direction == DIR_SELL) {
      if(Bid <= lastPrice - (curATR * PyramidingThresholdN)) {
         return true;
      }
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("PyramidingSignalGiven error: direction=%d",
            status.direction); 
      }
      return false;
   }

   return false;
}

double GetLastPrice(eStrategyType strategyType, sTradeStatus &status)
{
   int magic;
   if(strategyType == StrategyTypeS1) {
      magic = MagicNumber_System1;
   } else if(strategyType == StrategyTypeS2) {
      magic = MagicNumber_System2;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("GetLastPrice error: Invalid strategy type: %d", strategyType);
      }
      return -1.0;
   }
   
   for(int pos=OrdersTotal()-1; pos>=0; pos--)
   {   
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      
      if(OrderMagicNumber() == magic &&
          OrderSymbol() == Symbol())
      {
         int type = OrderType();
         if(type == OP_BUY ||
             type == OP_BUYLIMIT ||
             type == OP_BUYSTOP)
         {
            if(status.direction == DIR_SELL) {
               if(LogLevel >= LevelCritical) {
                  PrintFormat(
                     "Critical: GetLastPrice(%d): Looking for Sell oders but found Buy order!"
                  );
               }
               return -1.0;
            }
            
            datetime tmpOpenTime = OrderOpenTime();
            if(tmpOpenTime == status.lastTradeTime) {
               return OrderOpenPrice();
            }
         } else if (type == OP_SELL ||
                     type == OP_SELLLIMIT ||
                     type == OP_SELLSTOP)
         {
            if(status.direction == DIR_BUY) {
               if(LogLevel >= LevelCritical) {
                  PrintFormat(
                     "Critical: GetLastPrice(%d): Looking for Buy oders but found Sell order!"
                  );
               }
               return -1.0;
            }
            
            datetime tmpOpenTime = OrderOpenTime();
            if(tmpOpenTime == status.lastTradeTime) {
               return OrderOpenPrice();
            }
         }
      }
   }
   
   return -1.0;
}

int EnterPosition(eStrategyType strategyType, sTradeStatus &status)
{
   int magic;
   if(strategyType == StrategyTypeS1) {
      magic = MagicNumber_System1;
   } else if(strategyType == StrategyTypeS2) {
      magic = MagicNumber_System2;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("Error: CurrentlyTrading: Invalid strategy type: %d",
                     strategyType);
      }
      return -1;
   }
   
   double lotSize = GetLotSize(status);
   if(lotSize == -1.0) {
      if(LogLevel >= LevelError) {
         Print("EnterPosition: error lotSize");
      }
      return -1;
   }
   
   double stopSize = GetStopSize(status);
   if(stopSize == -1.0 || stopSize < 0) {
      if(LogLevel >= LevelError) {
         Print("EnterPosition: error stopSize");
      }
      return -1;
   }
   
   int ticketNr = -1;   
   if(status.direction == DIR_BUY) {
      ticketNr = OrderSend(
                  Symbol(),
                  OP_BUY,
                  lotSize,
                  Ask,
                  ttnDefaultSlippage,
                  stopSize,
                  0,
                  eaName,
                  magic,
                  0,
                  clrBlue
      );
   } else if(status.direction == DIR_SELL) {
      ticketNr = OrderSend(
                  Symbol(),
                  OP_SELL,
                  lotSize,
                  Bid,
                  ttnDefaultSlippage,
                  stopSize,
                  0,
                  eaName,
                  magic,
                  0,
                  clrRed
      ); 
   } else {
      if(LogLevel >= LevelError) {
         Print("EnterPosition: error direction=%d", status.direction);
      }
      return -1;
   }
   
   if(ticketNr == -1) {
      if(LogLevel >= LevelError) {
         PrintFormat("EnterPosition: Error opening order: %s",
            ErrorDescription(GetLastError()));
      }
      return -1;
   }  
   
   return ticketNr;
}

double GetLotSize(sTradeStatus &status)
{
   int periodOffset;
   if(status.openOffset == -2 ) {
      if(LogLevel >= LevelError) {
         Print("GetLotSize error: openOffset=-2"); 
      }
      return -1.0;
   } else if(status.openOffset < 1) {
      periodOffset = 1;
   } else {
      periodOffset = status.openOffset;
   }
   
   double curATR = iATR(NULL, 0, PeriodATR, periodOffset) / Point;
   if(curATR == 0.0) {
      if(LogLevel >= LevelError) {
         PrintFormat("GetLotSize error: ATR=%f", curATR); 
      }
      return -1.0;
   }
   
   double equityPerN = AccountBalance() *(EquityPctPerN / 100.0);
   double equityPerTrade = equityPerN * UnitsPerTrade;

   double tickValue = MarketInfo(Symbol(),MODE_TICKVALUE);

   double lotSize = equityPerTrade / (StopSizeInN * curATR * tickValue);
   
   if(MarketInfo(Symbol(),MODE_LOTSTEP) == 0.1)
   {
      lotSize = NormalizeDouble(lotSize,1);
   }
   else {
      lotSize = NormalizeDouble(lotSize,2);
   }
   
   if(lotSize < MarketInfo(Symbol(),MODE_MINLOT))
   {
      if(LogLevel >= LevelError) {
         PrintFormat("GetLotSize: lotSize=%f < MINLOT", lotSize);
      }
      return -1.0;
   } else if(lotSize > MarketInfo(Symbol(),MODE_MAXLOT))
   {
      lotSize = MarketInfo(Symbol(),MODE_MAXLOT);
      if(LogLevel >= LevelWarning) {
         PrintFormat("GetLotSize: lotSize=%f > MAXLOT=%f",
            lotSize, MarketInfo(Symbol(),MODE_MAXLOT));
      }
   }

   return lotSize;
}

double GetStopSize(sTradeStatus &status)
{
   int periodOffset;
   if(status.openOffset == -2 ) {
      if(LogLevel >= LevelError) {
         Print("GetStopSize error: openOffset=-2"); 
      }
      return -1.0;
   } else if(status.openOffset < 1) {
      periodOffset = 1;
   } else {
      periodOffset = status.openOffset;
   }
   
   double curATR = iATR(NULL, 0, PeriodATR, periodOffset);
   if(curATR == 0.0) {
      if(LogLevel >= LevelError) {
         PrintFormat("GetStopSize error: ATR=%f", curATR);
      }
      return -1.0;
   }
   
   double stopSize;
   double marketStopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL) * Point;
   
   if(status.direction == DIR_BUY) {
      stopSize = Bid - (StopSizeInN * curATR);
      if(stopSize > Ask - marketStopLevel) {
         PrintFormat("SL(%f) > Ask(%f) - minSL(%f)",
            stopSize, Ask, marketStopLevel);
         return -1.0;
      }
      return stopSize;
   } else if(status.direction == DIR_SELL) {
      stopSize = Ask + (StopSizeInN * curATR);
      if(stopSize < Bid + marketStopLevel) {
         PrintFormat("SL(%f) < Bid(%f) + minSL(%f)",
            stopSize, Bid, marketStopLevel);
         return -1.0;
      }
      return stopSize;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("GetStopSize error: direction=%d", status.direction);
      }
      return -1.0;
   }

   return -1.0;
}
