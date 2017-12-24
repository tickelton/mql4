//+------------------------------------------------------------------+
//|                             ttn-201705-cci_breakout_reversal.mq4 |
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

#property copyright "tickelton@gmail.com"
#property link      "https://github.com/tickelton"
#property strict

#include <stderror.mqh>
#include <stdlib.mqh>

#include <ttnCommon.mqh>
#include <ttnCommonFuncs.mqh>

extern int MagicNumber = ttnMagicNumber201705CCIbreakoutReversal;
extern eLogLevel LogLevel = LevelError;
extern double MinATR = 0.00050;
extern double MaxATRfactor = 6.0;
extern int MinCCI = 100;
extern int CCIbreakoutBars = 32;
extern double SignalATRmultiplier = 1.5;
extern double StopATRmultiplier = 0.5;
extern double TrailingATRmultiplier = 0.5;
extern double ProfitFactor = 0.5;

int CCIcutoff = 100;
double MaxATR;

int TicketNr1 = 0;
int TicketNr2 = 0;

bool NoLong = false;
bool NoShort = false;

const string eaName = "ttn-201705-cci_breakout_reversal";
datetime CurrentTimestamp;

struct sTradeData {
   int op;
   double openPrice;
   double stopLoss;
   double takeProfit;
   double trailingSL;
};

sTradeData TradeData;

int OnInit()
{
   CurrentTimestamp = Time[0];
   CCIcutoff = MinCCI;
   MaxATR = MinATR * MaxATRfactor;
   resetTradeData();
   
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   bool NewBar = false;

   if(CurrentTimestamp != Time[0]) {
      CurrentTimestamp = Time[0];
      NewBar = true;
   }

   if(NewBar) {
      if(TicketNr1 == 0 &&
          TicketNr2 == 0)
         checkSetup();
   }

   if(TicketNr1 != 0 ||
       TicketNr2 != 0)
      checkExits();
}

void checkSetup()
{
   double curATR = iATR(NULL, 0, 14, 1);
   double curCCI = iCCI(NULL, 0, 14, PRICE_TYPICAL, 1);

   if(curATR < MinATR || curATR > MaxATR)
      return;
   if(curCCI < CCIcutoff && curCCI > -CCIcutoff)
      return;
   if(directionLocked(curCCI))
      return;
   if(!gotCCIbreakout(curCCI))
      return;
   if(!gotEntryCandle(curATR, curCCI))
      return;
   if(trendingCCI())
      return;
   
   enterTrade(curCCI, curATR);
}

bool directionLocked(double curCCI)
{
   if(curCCI > 0 && NoLong)
      return true;
   if(curCCI < 0 && NoShort)
      return true;
   return false;
}

bool gotCCIbreakout(double curCCI)
{
   for(int i=2; i<=CCIbreakoutBars; i++) {
      double tmpCCI = iCCI(NULL, 0, 14, PRICE_TYPICAL, i);
      
      if(curCCI > 0 && curCCI < tmpCCI)
         return false;
      if(curCCI < 0 && curCCI > tmpCCI)
         return false;
   }
   
   if(LogLevel >= LevelDebug) {
      PrintFormat("gotCCIbreakout: got breakout cur=%f",
         curCCI
      );
   }
   return true;
}

bool gotEntryCandle(double curATR, double curCCI)
{
   if(curCCI > 0) {
      if(Close[1] <= Open[1])
         return false;
   } else {
      if(Close[1] >= Open[1])
         return false;
   }
   
   if(MathAbs(Close[1] - Open[1]) <
       (curATR * SignalATRmultiplier))
      return false;
   
   return true;
}

void resetTradeData()
{
   TradeData.openPrice = 0.0;
   TradeData.stopLoss = 0.0;
   TradeData.takeProfit = 0.0;
   TradeData.op = OP_NONE;
   TradeData.trailingSL = 0.0;
}

bool trendingCCI()
{
   return false;
}

void enterTrade(double curCCI, double curATR)
{
   color arrowColor;
   
   if(TradeData.openPrice != 0.0 ||
       TradeData.stopLoss != 0.0 ||
       TradeData.takeProfit != 0.0 ||
       TradeData.trailingSL != 0.0 ||
       TradeData.op != OP_NONE) {
      if(LogLevel >= LevelError) {
         PrintFormat("enterTrade: invalid CCI: %f",
            curCCI
         );
      }
   }
   
   if(curCCI < 0) {
      TradeData.op = OP_BUY;
      TradeData.openPrice = Ask;
      TradeData.stopLoss = Low[1] - (curATR * StopATRmultiplier);
      TradeData.takeProfit = Open[1] - ((Open[1] - Close[1]) * ProfitFactor);
      arrowColor = clrBlue;
   } else if(curCCI > 0) {
      TradeData.op = OP_SELL;
      TradeData.openPrice = Bid;
      TradeData.stopLoss = High[1] + (curATR * StopATRmultiplier);   
      TradeData.takeProfit = Open[1] + ((Close[1] - Open[1]) * ProfitFactor);
      arrowColor = clrRed;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("enterTrade: invalid CCI: %f",
            curCCI
         );
      }
      return;
   }
   
   if(LogLevel >= LevelDebug) {
      PrintFormat("enterTrade: Open op=%d price=%f SL=%f TP=%f ATR=%f CCI=%f",
         TradeData.op,
         TradeData.openPrice,
         TradeData.stopLoss,
         TradeData.takeProfit,
         curATR,
         curCCI
      );
   }
   TicketNr1 = OrderSend(
         Symbol(),
         TradeData.op,
         0.5,
         TradeData.openPrice,
         3,
         0,
         0,
         eaName,
         MagicNumber,
         0,
         arrowColor
   );
   
   if(TicketNr1 == -1) {
      PrintFormat("EnterPosition: Error opening order: %s",
         ErrorDescription(GetLastError()));
      TicketNr1 = 0;
      return;
   }
   
   TicketNr2 = OrderSend(
         Symbol(),
         TradeData.op,
         0.5,
         TradeData.openPrice,
         3,
         0,
         0,
         eaName,
         MagicNumber,
         0,
         arrowColor
   );
   
   if(TicketNr2 == -1) {
      PrintFormat("EnterPosition: Error opening order: %s",
         ErrorDescription(GetLastError()));
      TicketNr2 = 0;
      closeTicket(TicketNr1);
      TicketNr1 = 0;
      return;
   }
}

void closeTicket(int nr)
{
   if(TradeData.op == OP_BUY) {
      if(!OrderClose(nr, 0.5, Bid, 0, clrRed)) {
         PrintFormat("EnterPosition: Error closing order: %s",
            ErrorDescription(GetLastError()));
      }
   } else if(TradeData.op == OP_SELL) {
      if(!OrderClose(nr, 0.5, Ask, 0, clrRed)) {
         PrintFormat("EnterPosition: Error closing order: %s",
            ErrorDescription(GetLastError()));
      }
   }
   
   if(nr == TicketNr2)
      resetTradeData();
}

void setTrailingSL()
{
   double curATR = iATR(NULL, 0, 14, 1);
   
   if(TradeData.op == OP_BUY) {
      double slPrice = NormalizeDouble(
         Bid - (TrailingATRmultiplier * curATR),
         Digits
      );
      
      if(slPrice <= TradeData.openPrice)
         return;
      if(TradeData.trailingSL != 0.0 &&
          slPrice <= TradeData.trailingSL)
         return;
      TradeData.trailingSL = slPrice;
   } else if(TradeData.op == OP_SELL) {
      double slPrice = NormalizeDouble(
         Ask + (TrailingATRmultiplier * curATR),
         Digits
      );
      
      if(slPrice >= TradeData.openPrice)
         return;
      if(TradeData.trailingSL != 0.0 &&
          slPrice >= TradeData.trailingSL)
         return;
      TradeData.trailingSL = slPrice;
   }
}

void checkExits()
{
   if(TicketNr1 != 0) {
      if(TradeData.op == OP_BUY) {
         if(Bid <= TradeData.stopLoss) {
            closeTicket(TicketNr1);
            TicketNr1 = 0;
         } else if(Bid >= TradeData.takeProfit) {
            closeTicket(TicketNr1);
            TicketNr1 = 0;
            setTrailingSL();
         }
      } else if(TradeData.op == OP_SELL) {
         if(Ask >= TradeData.stopLoss) {
            closeTicket(TicketNr1);
            TicketNr1 = 0;
         } else if (Ask <= TradeData.takeProfit) {
            closeTicket(TicketNr1);
            TicketNr1 = 0;
            setTrailingSL();
         }
      }
   } else {
      setTrailingSL();   
   }
   
   if(TicketNr2 != 0) {
      if(TradeData.op == OP_BUY) {
         if(Bid <= TradeData.stopLoss ||
             (TradeData.trailingSL != 0.0 && Bid <= TradeData.trailingSL)) {
            closeTicket(TicketNr2);
            TicketNr2 = 0;
            resetTradeData();
         }
      } else if(TradeData.op == OP_SELL) {
         if(Ask >= TradeData.stopLoss ||
             (TradeData.trailingSL != 0.0 && Ask >= TradeData.trailingSL)) {
            closeTicket(TicketNr2);
            TicketNr2 = 0;
            resetTradeData();
         }
      }
   }
}
