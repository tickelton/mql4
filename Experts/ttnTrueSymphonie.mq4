//+------------------------------------------------------------------+
//|                                             ttnTrueSymphonie.mq4 |
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

extern int MagicNumber = ttnMagicNumberTrueSymphonie;
extern int MAPeriodSlow = 72;
extern int MAPeriodFast = 12;
extern ENUM_MA_METHOD MAMethodSlow = MODE_SMA;
extern ENUM_MA_METHOD MAMethodFast = MODE_EMA;
extern double SlowATRThreshold = 1.0;
extern double FastATRThreshold = 2.0;
extern int ATRPeriod = 14;
extern int ValidityTimeout = 4;
extern double EquityPctPerN = 1.0;
extern int UnitsPerTrade = 1;
extern int MaxUnitsPerCurrencyPair = 4;
extern int MaxUnitStronglyCorrelated = 5;
extern int MaxUnitMildlyCorrelated = 7;
extern int MaxUnitsPerDirection = 10;
extern eLogLevel LogLevel = LevelError;

struct sOrderStatus {
   int ticketNr;
   double risk;
   double openPrice;
   eTradeDirection direction;
};

struct sTradeStatus {
   int openOffset;
   datetime lastTradeTime;
   eTradeDirection direction;
};

const string eaName = "ttnTrueSymphonie";
datetime CurrentTimestamp;
sOrderStatus OrderStatus;


int OnInit()
{
   CurrentTimestamp = Time[0];
   OrderStatus.ticketNr = 0;
   OrderStatus.openPrice = 0;
   OrderStatus.risk = 0;
   OrderStatus.direction = DIR_NONE;
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{

   
}

void OnTick()
{
   bool NewBar = false;

   if(CurrentTimestamp != Time[0]) {
      CurrentTimestamp = Time[0];
      NewBar = true;
   }
   
   if(NewBar) {  
      CheckEntry();   
   }
   
   CheckStopLevel();
   CheckExit();
}

void CheckEntry()
{
   sTradeStatus tradeStatus = CurrentlyTrading();
   if(tradeStatus.openOffset > -1) {
/*
      if(GotFreeVolume(tradeStatus)) {
         CheckPyramiding(strategyType, tradeStatus);
      }
*/
   } else if(tradeStatus.openOffset == -1) {
      eTradeDirection tmpDir = EntrySignalGiven();
      if(tmpDir != DIR_NONE) {
         tradeStatus.direction = tmpDir;
         if(GotFreeVolume(tradeStatus)) {
            if(EnterPosition(tradeStatus) == -1) {
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

sTradeStatus CurrentlyTrading()
{
   sTradeStatus tradeStatus;
   tradeStatus.openOffset = -2;
   tradeStatus.direction = DIR_NONE;
   
   bool gotBullOrders = false;
   bool gotBearOrders = false;
   
   for(int pos=OrdersTotal()-1; pos>=0; pos--)
   {   
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      
      if(OrderMagicNumber() == MagicNumber &&
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
         Print(
            "Critical: CurrentlyTrading(): Open orders in both directions!"
         );
      }
      tradeStatus.openOffset = -2;
   } else if(gotBearOrders && !gotBullOrders) {
      tradeStatus.direction = DIR_SELL;
      GetOrderStatus(tradeStatus);
   } else if(!gotBearOrders && gotBullOrders) {
      tradeStatus.direction = DIR_BUY;
      GetOrderStatus(tradeStatus);
   } else {
      if(LogLevel >= LevelCritical) {
         Print(
            "Critical: CurrentlyTrading(%d): This should not happen!"
         );
      }
      tradeStatus.openOffset = -2;
   }

   return tradeStatus;
}

void GetOrderStatus(sTradeStatus &status)
{
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
      
      if(OrderMagicNumber() == MagicNumber &&
          OrderSymbol() == Symbol())
      {
         int type = OrderType();
         if(type == OP_BUY ||
             type == OP_BUYLIMIT ||
             type == OP_BUYSTOP)
         {
            if(status.direction == DIR_SELL) {
               if(LogLevel >= LevelCritical) {
                  Print(
                     "Critical: GetOpenOffset(): Looking for Sell oders but found Buy order!"
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
                  Print(
                     "Critical: GetOpenOffset(): Looking for Buy oders but found Sell order!"
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

eTradeDirection EntrySignalGiven()
{
   double tmpATR = iATR(NULL, 0, ATRPeriod, 1);
   double tmpSlowMA = iMA(NULL, 0, MAPeriodSlow, 0, MAMethodSlow, PRICE_TYPICAL, 1);
   double lowSlow = tmpSlowMA - (tmpATR * FastATRThreshold);
   double lowFast = iMA(NULL, 0, MAPeriodFast, 0, MAMethodFast, PRICE_LOW, 1);
   double highSlow = tmpSlowMA + (tmpATR * FastATRThreshold);
   double highFast = iMA(NULL, 0, MAPeriodFast, 0, MAMethodFast, PRICE_HIGH, 1);
   
   if(Open[1] > highSlow && Open[1] > highFast &&
       Close[1] > Open[1]) {
      double prevATR = iATR(NULL, 0, ATRPeriod, 2);
      double prevSlowMA = iMA(NULL, 0, MAPeriodSlow, 0, MAMethodSlow, PRICE_TYPICAL, 2);
      double prevHighSlow = prevSlowMA + (prevATR * FastATRThreshold);
      double prevHighFast = iMA(NULL, 0, MAPeriodFast, 0, MAMethodFast, PRICE_HIGH, 2);
      if(Close[2] > prevHighFast && Close[2] > prevHighSlow) {
         return DIR_BUY;
      }
   } else if (Open[1] < lowSlow && Open[1] < lowFast &&
       Close[1] < Open[1]) {
      double prevATR = iATR(NULL, 0, ATRPeriod, 2);
      double prevSlowMA = iMA(NULL, 0, MAPeriodSlow, 0, MAMethodSlow, PRICE_TYPICAL, 2);
      double prevLowSlow = prevSlowMA - (prevATR * FastATRThreshold);
      double prevLowFast = iMA(NULL, 0, MAPeriodFast, 0, MAMethodFast, PRICE_LOW, 2);
      if(Close[2] < prevLowFast && Close[2] < prevLowSlow) {
         return DIR_SELL;
      }
   }
   
   return DIR_NONE;
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
            if(orderMagic == MagicNumber) {
               unitsDirection++;   
            }
         }
      } else if (type == OP_SELL)
      {
         tmpRisk = ((OrderStopLoss() - OrderOpenPrice()) * OrderLots() * tickValue) / Point;
         if(tradeStatus.direction == DIR_SELL) {
            equityDirection += tmpRisk;
            if(orderMagic == MagicNumber) {
               unitsDirection++;   
            }
         }
      }
      
      if(!StringCompare(Symbol(), OrderSymbol())) {
         equityPair += tmpRisk;
         if(orderMagic == MagicNumber) {
            unitsPair++;   
         }
      }
      if(IsCorrelated(Symbol(), OrderSymbol(), CORRELATION_MILD)) {
         equityMildCorrelation += tmpRisk;
         if(orderMagic == MagicNumber) {
            unitsMildCorrelation++;   
         }
      }
      if(IsCorrelated(Symbol(), OrderSymbol(), CORRELATION_STRONG)) {
         equityStrongCorrelation += tmpRisk;
         if(orderMagic == MagicNumber) {
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

int EnterPosition(sTradeStatus &status)
{
   double stopLevel = GetStopLevel(status);
   if(stopLevel == -1.0 || stopLevel < 0) {
      if(LogLevel >= LevelError) {
         Print("EnterPosition: error stopLevel");
      }
      return -1;
   }

   
   int ticketNr = -1;   
   double stopSize;
   if(status.direction == DIR_BUY) {
      stopSize = (Ask - stopLevel) / Point;    
      double lotSize = GetLotSize(stopSize, status);
      if(lotSize == -1.0) {
         if(LogLevel >= LevelError) {
            Print("EnterPosition: error lotSize");
         }
         return -1;
      }

      ticketNr = OrderSend(
                  Symbol(),
                  OP_BUY,
                  lotSize,
                  Ask,
                  ttnDefaultSlippage,
                  stopLevel,
                  0,
                  eaName,
                  MagicNumber,
                  0,
                  clrBlue
      );
   } else if(status.direction == DIR_SELL) {
      stopLevel += (Ask - Bid);
      stopSize = (stopLevel - Bid) / Point;
      double lotSize = GetLotSize(stopSize, status);
      if(lotSize == -1.0) {
         if(LogLevel >= LevelError) {
            Print("EnterPosition: error lotSize");
         }
         return -1;
      }
      
      ticketNr = OrderSend(
                  Symbol(),
                  OP_SELL,
                  lotSize,
                  Bid,
                  ttnDefaultSlippage,
                  stopLevel,
                  0,
                  eaName,
                  MagicNumber,
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
   
   if(OrderSelect(ticketNr, SELECT_BY_TICKET) == false) {
      OrderStatus.ticketNr = 0;
      OrderStatus.openPrice = 0;
      OrderStatus.risk = 0;
      OrderStatus.direction = DIR_NONE;
   } else {
      OrderStatus.ticketNr = ticketNr;
      OrderStatus.openPrice = OrderOpenPrice();
      if(status.direction == DIR_BUY) {
         OrderStatus.risk = OrderStatus.openPrice - OrderStopLoss();
         OrderStatus.direction = DIR_BUY;
      } else if(status.direction == DIR_SELL) {
         OrderStatus.risk = OrderStopLoss() - OrderStatus.openPrice;
         OrderStatus.direction = DIR_SELL;
      }
   }
   
   return ticketNr;
}

double GetStopLevel(sTradeStatus &status)
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
      
   double stopSize;
   double stopLevel;
   double marketStopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL) * Point;

   if(status.direction == DIR_BUY) {
      stopLevel = iMA(NULL, 0, MAPeriodFast, 0, MAMethodFast, PRICE_HIGH, periodOffset);
      stopSize = (Bid - stopLevel);
      if(stopSize < marketStopLevel) {
         PrintFormat("SL(%f) < minSL(%f)",
            stopSize, marketStopLevel);
         return -1.0;
      }
      return stopLevel;
   } else if(status.direction == DIR_SELL) {
      stopLevel = iMA(NULL, 0, MAPeriodFast, 0, MAMethodFast, PRICE_LOW, periodOffset);
      stopSize = (stopLevel - Ask);
      if(stopSize < marketStopLevel) {
         PrintFormat("SL(%f) < minSL(%f)",
            stopSize, marketStopLevel);
         return -1.0;
      }
      return stopLevel;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("GetStopSize error: direction=%d", status.direction);
      }
      return -1.0;
   }

   return -1.0;
}

double GetLotSize(double stopSize, sTradeStatus &status)
{   
   double equityPerN = AccountBalance() *(EquityPctPerN / 100.0);
   double equityPerTrade = equityPerN * UnitsPerTrade;

   double tickValue = MarketInfo(Symbol(),MODE_TICKVALUE);

   double lotSize = equityPerTrade / (stopSize * tickValue);
   
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

void CheckStopLevel()
{
   sTradeStatus tradeStatus = CurrentlyTrading();
   if(tradeStatus.openOffset <= -1) {
      return;
   }
   
   if(OrderStatus.ticketNr == 0) {
         return;
   }
   
   double newSL = 0.0;
   if(OrderStatus.direction == DIR_BUY) {
      if(Bid >= OrderStatus.openPrice + (OrderStatus.risk * 2.5)) {
         newSL = OrderStatus.openPrice + ((Bid - OrderStatus.openPrice) * 0.66);
      } else if(Bid >= OrderStatus.openPrice + (OrderStatus.risk * 1.5)) {
         newSL = OrderStatus.openPrice + ((Bid - OrderStatus.openPrice) * 0.4);
      } else if(Bid >= OrderStatus.openPrice + (OrderStatus.risk * 0.5)) {
         newSL = OrderStatus.openPrice;
      }
   } else if(OrderStatus.direction == DIR_SELL) {
      if(Bid <= OrderStatus.openPrice - (OrderStatus.risk * 1.5)) {
         newSL = OrderStatus.openPrice - ((OrderStatus.openPrice - Bid) * 0.66);
      } else if(Bid <= OrderStatus.openPrice - (OrderStatus.risk * 1.5)) {
         newSL = OrderStatus.openPrice - ((OrderStatus.openPrice - Bid) * 0.4);
      } else if(Bid <= OrderStatus.openPrice - (OrderStatus.risk * 0.5)) {
         newSL = OrderStatus.openPrice;
      }
   }
   
   newSL = NormalizeDouble(newSL, Digits);
   if(newSL > 0.0) {
      if(OrderSelect(OrderStatus.ticketNr, SELECT_BY_TICKET) == false) {
         Print("CheckStopLevel Error: error selecting order ", ErrorDescription(GetLastError()));
         return;
      }
      if(OrderStatus.direction == DIR_BUY &&
          newSL > OrderStopLoss()) {
         if(!OrderModify(OrderStatus.ticketNr, OrderOpenPrice(), NormalizeDouble(newSL, Digits), OrderTakeProfit(), 0, clrYellow)) {
            Print("CheckStopLevel Error: error trailing SL ", ErrorDescription(GetLastError()));
            return;
         }
      } else if(OrderStatus.direction == DIR_SELL &&
          newSL < OrderStopLoss()) {
         if(!OrderModify(OrderStatus.ticketNr, OrderOpenPrice(), NormalizeDouble(newSL, Digits), OrderTakeProfit(), 0, clrYellow)) {
            Print("CheckStopLevel Error: error trailing SL ", ErrorDescription(GetLastError()));
            return;
         }
      }
   }
   
   return;
}

void InitOrderStatus()
{

}

void CheckExit()
{
   sTradeStatus tradeStatus = CurrentlyTrading();
   if(tradeStatus.openOffset <= -1) {
      return;
   }
   
   if(OrderStatus.direction == DIR_BUY) {
      double tmpATR = iATR(NULL, 0, ATRPeriod, 1);
      double tmpMA = iMA(NULL, 0, MAPeriodFast, 0, MAMethodFast, PRICE_TYPICAL, 1);
      double stopVal = tmpMA - (tmpATR * SlowATRThreshold);
      if(Bid < stopVal) {
         if(OrderSelect(OrderStatus.ticketNr, SELECT_BY_TICKET) == false) {
            Print("CheckExit Error: error selecting order ", ErrorDescription(GetLastError()));
            return;
         }
         if(!OrderClose(OrderTicket(), OrderLots(), Bid, ttnDefaultSlippage, ttnClrBuyClose)) {
            if(LogLevel >= LevelError) {
               Print("Error: Cannot close order: " + ErrorDescription(GetLastError()));
            }
         }
      }
   } else if(OrderStatus.direction == DIR_SELL) {
      double tmpATR = iATR(NULL, 0, ATRPeriod, 1);
      double tmpMA = iMA(NULL, 0, MAPeriodFast, 0, MAMethodFast, PRICE_TYPICAL, 1);
      double stopVal = tmpMA + (tmpATR * SlowATRThreshold);
      if(Bid > stopVal) {
         if(OrderSelect(OrderStatus.ticketNr, SELECT_BY_TICKET) == false) {
            Print("CheckExit Error: error selecting order ", ErrorDescription(GetLastError()));
            return;
         }
         if(!OrderClose(OrderTicket(), OrderLots(), Ask, ttnDefaultSlippage, ttnClrBuyClose)) {
            if(LogLevel >= LevelError) {
               Print("Error: Cannot close order: " + ErrorDescription(GetLastError()));
            }
         }
      }
   }
   
   return;
}
