//+------------------------------------------------------------------+
//|                                  ttn-201705-plateau_reversal.mq4 |
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

extern int MagicNumber = ttnMagicNumber201705plateauReversal;
extern eLogLevel LogLevel = LevelError;
extern int PlateauLength1 = 60;
extern int PlateauLength2 = 30;
extern double MinPriceDiff = 0.00100;
extern double ExtremeDiffMultiplier = 2.0;
extern int BreakoutTime = 15;
extern double MaxPlateauSlope = 0.000001;
extern int EntryConfirmationBars = 10;
extern int PeriodATR = 14;
extern double TrailingSLDivisor = 0.25;
extern bool AdaptiveShortTP = true;
extern double StopATRmultiplier = 1.0;
extern int TimeExit = 90;

int ticketNr1 = 0;
int ticketNr2 = 0;

double takeProfitLevel = 0.0;
double trailingStopLevel = 0.0;

const string eaName = "ttn-201705-plateau_reversal";
datetime CurrentTimestamp;

struct sEntryData {
   int dir;
   s_linereg p1;
   s_linereg p2;
   double stopLevel;
   double trailingSL;
   double entrySecondQuarter;
   datetime triggerTime;
};
sEntryData EntryData;

int OnInit()
{
   CurrentTimestamp = Time[0];
   resetEntryData();
   
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
      if(ticketNr1 != 0 ||
          ticketNr2 != 0) {
         checkTimeExit();
      } else if(EntryData.dir != OP_NONE) {
         if(getTimeDiff(CurrentTimestamp, EntryData.triggerTime) > EntryConfirmationBars) {
            EntryData.dir = OP_NONE;
            EntryData.stopLevel = 0.0;
         } else {
            checkEntryTrigger();
         }
      } else {
         checkPlateau();
      }
   }
   
   if(ticketNr1 != 0 ||
       ticketNr2 != 0) {
      checkPriceExits();
   }   
}

void resetEntryData()
{
   EntryData.dir = OP_NONE;
   EntryData.stopLevel = 0.0;
   EntryData.trailingSL = 0.0;
}

void checkTimeExit()
{
   if(ticketNr1 == 0)
      return;
      
   OrderSelect(ticketNr1, SELECT_BY_TICKET);
   int timeDiff = getTimeDiff(CurrentTimestamp, OrderOpenTime());
   
   if(timeDiff >= TimeExit) {
      closeTicket(ticketNr1);
      ticketNr1 = 0;
      closeTicket(ticketNr2);
      ticketNr2 = 0;
      resetEntryData();
   }
}

void checkPriceExits()
{
   if(ticketNr1 != 0) {
      if(EntryData.dir == OP_BUY) {
         if(Bid <= EntryData.stopLevel) {
            LogTerminal(LevelDebug,
               LogLevel,
               "checkPriceExits: 1 Bid <= EntryData.stopLevel"
            );
            closeTicket(ticketNr1);
            ticketNr1 = 0;
         } else if(Bid >= takeProfitLevel) {
            LogTerminal(LevelDebug,
               LogLevel,
               "checkPriceExits: 1 Bid >= takeProfitLevel"
            );
            closeTicket(ticketNr1);
            ticketNr1 = 0;
            trailingStopLevel = NormalizeDouble(
               Bid - EntryData.trailingSL,
               Digits
            );
            if(LogLevel >= LevelDebug)
               PrintFormat(
               "checkPriceExits: set TSL=%f",
               trailingStopLevel
               );
         }
      } else if(EntryData.dir == OP_SELL) {
         if(Ask >= EntryData.stopLevel) {
            LogTerminal(LevelDebug,
               LogLevel,
               "checkPriceExits: 1 Ask >= EntryData.stopLevel"
            );
            closeTicket(ticketNr1);
            ticketNr1 = 0;
         } else if (Ask <= takeProfitLevel) {
            LogTerminal(LevelDebug,
               LogLevel,
               "checkPriceExits: 1 Ask <= takeProfitLevel"
            );
            closeTicket(ticketNr1);
            ticketNr1 = 0;
            trailingStopLevel = NormalizeDouble(
               Ask + EntryData.trailingSL,
               Digits
            );
            if(LogLevel >= LevelDebug)
               PrintFormat(
               "checkPriceExits: set TSL=%f",
               trailingStopLevel
               );
         }
      }
   } else {
      if(EntryData.dir == OP_BUY) {
         double newTrailingStopLevel = NormalizeDouble(
            Bid - EntryData.trailingSL,
            Digits
         );
         if(newTrailingStopLevel > trailingStopLevel) {
            trailingStopLevel = newTrailingStopLevel;
            if(LogLevel >= LevelTrace)
               PrintFormat(
               "checkPriceExits: re-set TSL=%f",
               trailingStopLevel
               );
         }
      } else if(EntryData.dir == OP_SELL) {
         double newTrailingStopLevel = NormalizeDouble(
            Ask + EntryData.trailingSL,
            Digits
         );
         if(newTrailingStopLevel < trailingStopLevel) {
            trailingStopLevel = newTrailingStopLevel;
            if(LogLevel >= LevelTrace)
               PrintFormat(
               "checkPriceExits: re-set TSL=%f",
               trailingStopLevel
               );
         }
      }      
   }
   
   if(ticketNr2 != 0) {
      if(EntryData.dir == OP_BUY) {
         if(Bid <= EntryData.stopLevel ||
             (trailingStopLevel != 0.0 && Bid <= trailingStopLevel)) {
            LogTerminal(LevelDebug,
               LogLevel,
               "checkPriceExits: 2 Bid <= EntryData.stopLevel"
            );
            closeTicket(ticketNr2);
            ticketNr2 = 0;
            resetEntryData();
         }
      } else if(EntryData.dir == OP_SELL) {
         if(Ask >= EntryData.stopLevel ||
             (trailingStopLevel != 0.0 && Ask >= trailingStopLevel)) {
            LogTerminal(LevelDebug,
               LogLevel,
               "checkPriceExits: 2 Ask >= EntryData.stopLevel"
            );
            closeTicket(ticketNr2);
            ticketNr2 = 0;
            resetEntryData();
         }
      }
   }
}

void checkPlateau()
{
   LogTerminal(LevelTrace, LogLevel, ">checkPlateau()");
   s_linereg plateau1 = linereg(PlateauLength1+PlateauLength2+BreakoutTime+1,
                                PlateauLength2+BreakoutTime+1);
   s_linereg plateau2 = linereg(PlateauLength2, 1);
   
   double cDiff = closeDiff(PlateauLength2+BreakoutTime,
                     PlateauLength2);
   double eDiff = extremeDiff(PlateauLength2+BreakoutTime,
                     PlateauLength2);
   double lineDiff = 0.0;
   if(plateau1.b > plateau2.b)
      lineDiff = plateau1.b - plateau2.b;
   else
      lineDiff = plateau2.b - plateau1.b;
   
   if(plateau1.m < MaxPlateauSlope &&
       plateau2.m < MaxPlateauSlope &&
       plateau1.m > -MaxPlateauSlope &&
       plateau2.m > -MaxPlateauSlope &&
       lineDiff >= MinPriceDiff &&
       eDiff <= lineDiff * ExtremeDiffMultiplier) {
      
      if(plateau1.b > plateau2.b) {
         double low1 = getRangeMax(
                        PlateauLength2+BreakoutTime+1,
                        PlateauLength1+PlateauLength2+BreakoutTime+1,
                        PRICE_LOW);
         double high2 = getRangeMax(
                        1,
                        PlateauLength2,
                        PRICE_HIGH);
         if(low1 < plateau2.b ||
             high2 > plateau1.b) {
            if(LogLevel >= LevelDebug)
                  PrintFormat(
                  "checkPlateau: Buy: plateau levels crossing: b1=%f b2=%f low1=%f high2=%f",
                  plateau1.b, plateau2.b, low1, high2
            );
            return;   
         }           
      } else {
         double high1 = getRangeMax(
                        PlateauLength2+BreakoutTime+1,
                        PlateauLength1+PlateauLength2+BreakoutTime+1,
                        PRICE_HIGH);
         double low2 = getRangeMax(
                        1,
                        PlateauLength2,
                        PRICE_LOW);
         if(high1 > plateau2.b ||
             low2 < plateau1.b) {
            if(LogLevel >= LevelDebug)
                  PrintFormat(
                  "checkPlateau: Sell: plateau levels crossing: b1=%f b2=%f high1=%f low2=%f",
                  plateau1.b, plateau2.b, high1, low2
            );
            return;   
         }  
      }
      drawPlateau(plateau1, plateau2);
      setEntryTrigger(plateau1, plateau2);
   }
   
   LogTerminal(LevelTrace, LogLevel, "<checkPlateau()");
}

double getRangeMax(int begin, int end, int applied_price)
{
   double max = 0.0;
   
   if(applied_price == PRICE_HIGH) {
      max = High[end];
      for(int i = begin; i < end; i++) {
         if(High[i] > max)
            max = High[i];
      }
   } else if(applied_price == PRICE_LOW) {
      max = Low[end];
      for(int i = begin; i < end; i++) {
         if(Low[i] < max)
            max = Low[i];
      }
   } else if(applied_price == PRICE_CLOSE) {
      max = Close[end];
      for(int i = begin; i < end; i++) {
         if(Close[i] < max)
            max = Close[i];
      }
   }
   
   return max;
}

void setEntryTrigger(s_linereg &plateau1, s_linereg &plateau2)
{
   LogTerminal(LevelTrace, LogLevel, ">setEntryTrigger()");
   
   double curATR = iATR(NULL, 0, PeriodATR, 1);
   
   if(plateau1.b < plateau2.b) {
      EntryData.dir = OP_SELL;
      EntryData.stopLevel = getRangeMax(1, PlateauLength2, PRICE_HIGH) + curATR*StopATRmultiplier;
      EntryData.trailingSL = NormalizeDouble(
         (plateau2.b - plateau1.b) * TrailingSLDivisor,
         Digits
      );
      takeProfitLevel = NormalizeDouble(
         plateau1.b + ((plateau2.b - plateau1.b)/2.0),
         Digits
      );
      EntryData.entrySecondQuarter = NormalizeDouble(
         plateau2.b - ((plateau2.b - plateau1.b)/4.0),
         Digits
      );
      if(LogLevel >= LevelDebug) {
         PrintFormat("setEntryTrigger: Sell SL=%f TSL=%f TP=%f",
            EntryData.stopLevel,
            EntryData.trailingSL,
            takeProfitLevel
         );
      }
   } else {
      EntryData.dir = OP_BUY;
      EntryData.stopLevel = getRangeMax(1, PlateauLength2, PRICE_LOW) - curATR*StopATRmultiplier;
      EntryData.trailingSL = NormalizeDouble(
         (plateau1.b - plateau2.b) * TrailingSLDivisor,
         Digits
      );
      takeProfitLevel = NormalizeDouble(
         plateau1.b - ((plateau1.b - plateau2.b)/2.0),
         Digits
      );
      EntryData.entrySecondQuarter = NormalizeDouble(
         plateau2.b + ((plateau1.b - plateau2.b)/4.0),
         Digits
      );
      if(LogLevel >= LevelDebug) {
         PrintFormat("setEntryTrigger: Buy SL=%f TSL=%f TP=%f",
            EntryData.stopLevel,
            EntryData.trailingSL,
            takeProfitLevel
         );
      }
   }
     
   EntryData.p1 = plateau1;
   EntryData.p2 = plateau2;
   EntryData.triggerTime = CurrentTimestamp;
   
   LogTerminal(LevelTrace, LogLevel, "<setEntryTrigger()");
}

void checkEntryTrigger()
{
   LogTerminal(LevelTrace, LogLevel, ">checkEntryTrigger()");
   
   if(EntryData.dir == OP_BUY) {
      if(Close[1] > Open[1] &&
          Close[1] > EntryData.p2.b) {
         if(Close[1] >= takeProfitLevel) {
            resetEntryData();
         } else {
            /* ONLY SEEMS TO WORK ON THE SHORT SIDE
               WARNING: possibly curve fitting !
            if(Close[1] > EntryData.entrySecondQuarter) {
               if(LogLevel >= LevelDebug) {
                  PrintFormat("checkEntryTrigger: Buy re-setting TF from %f to %f (sq=%f)",
                     takeProfitLevel,
                     NormalizeDouble(
                        EntryData.p1.b - ((EntryData.p1.b - EntryData.p2.b)/4.0),
                        Digits
                     ),
                     EntryData.entrySecondQuarter
                  );
               }
               takeProfitLevel = NormalizeDouble(
                  EntryData.p1.b - ((EntryData.p1.b - EntryData.p2.b)/4.0),
                  Digits
               );
            } */
            if(LogLevel >= LevelDebug) {
               PrintFormat("checkEntryTrigger: Buy SLwidth=%.5f PlateuDiff=%.5f",
                  Ask - EntryData.stopLevel,
                  EntryData.p1.b - EntryData.p2.b
               );
            }
            enterTrade();
         }
      }
   } else {
      if(Close[1] < Open[1] &&
          Close[1] < EntryData.p2.b) {
         if(Close[1] <= takeProfitLevel) {
            resetEntryData();
         } else {
            if(AdaptiveShortTP && Close[1] < EntryData.entrySecondQuarter) {
               if(LogLevel >= LevelDebug) {
                  PrintFormat("checkEntryTrigger: Sell re-setting TF from %f to %f (sq=%f)",
                     takeProfitLevel,
                     NormalizeDouble(
                        EntryData.p1.b + ((EntryData.p2.b - EntryData.p1.b)/4.0),
                        Digits
                     ),
                     EntryData.entrySecondQuarter
                  );
               }
               takeProfitLevel = NormalizeDouble(
                  EntryData.p1.b + ((EntryData.p2.b - EntryData.p1.b)/4.0),
                  Digits
               );
            }
            if(LogLevel >= LevelDebug) {
               PrintFormat("checkEntryTrigger: Sell SLwidth=%.5f PlateuDiff=%.5f",
                  EntryData.stopLevel - Bid,
                  EntryData.p2.b - EntryData.p1.b
               );
            }
            enterTrade();
         }
      }
   }
   
   LogTerminal(LevelTrace, LogLevel, "<checkEntryTrigger()");
}

void enterTrade()
{
   double orderPrice;
   color arrowColor;
   
   if(EntryData.dir == OP_BUY) {
      orderPrice = Ask;   
      arrowColor = clrBlue;
   } else if(EntryData.dir == OP_SELL) {
      orderPrice = Bid;
      arrowColor = clrRed;
   } else {
      LogTerminal(LevelCritical, LogLevel, "CRITICAL: enterTrade: dir = OP_NONE!");
      return;
   }
   
   ticketNr1 = OrderSend(
         Symbol(),
         EntryData.dir,
         0.5,
         orderPrice,
         3,
         0,
         0,
         eaName,
         MagicNumber,
         0,
         arrowColor
   );
   
   if(ticketNr1 == -1) {
      PrintFormat("EnterPosition: Error opening order: %s",
         ErrorDescription(GetLastError()));
      ticketNr1 = 0;
      return;
   }
   
   ticketNr2 = OrderSend(
         Symbol(),
         EntryData.dir,
         0.5,
         orderPrice,
         3,
         0,
         0,
         eaName,
         MagicNumber,
         0,
         arrowColor
   );
   
   if(ticketNr2 == -1) {
      PrintFormat("EnterPosition: Error opening order: %s",
         ErrorDescription(GetLastError()));
      ticketNr2 = 0;
      closeTicket(ticketNr1);
      ticketNr1 = 0;
      return;
   }
}

void closeTicket(int nr)
{
   if(EntryData.dir == OP_BUY) {
      if(!OrderClose(nr, 0.5, Bid, 0, clrRed)) {
         PrintFormat("EnterPosition: Error closing order: %s",
            ErrorDescription(GetLastError()));
      }
   } else if(EntryData.dir == OP_SELL) {
      if(!OrderClose(nr, 0.5, Ask, 0, clrRed)) {
         PrintFormat("EnterPosition: Error closing order: %s",
            ErrorDescription(GetLastError()));
      }
   }
   
   if(nr == ticketNr2) {
      trailingStopLevel = 0.0;
   }
}

double closeDiff(int begin, int end)
{
   double close1 = Close[begin];
   double close2 = Close[end];
   
   if(close2 > close1)
      return close2 - close1;
   else
      return close1 - close2;
}

double extremeDiff(int begin, int end)
{
   double maxHigh = High[begin];
   double maxLow = Low[end];
   
   for(int i=begin+1; i<=end; i++) {
      if(High[i] > maxHigh)
         maxHigh = High[i];
      if(Low[i] < maxLow)
         maxLow = Low[i];
   }
   
   return maxHigh - maxLow;
}

void drawPlateau(s_linereg &plateau1, s_linereg &plateau2)
{
   static int count = 1;
   
   string lineName1 = "l_plateau1_";
   string lineName2 = "l_plateau2_";
   
   if(LogLevel >= LevelDebug)
      PrintFormat("Plateau1: m=%f b=%f r=%f", plateau1.m, plateau1.b, plateau1.r);
   if(!ObjectCreate(0,
         StringConcatenate(lineName1, IntegerToString(count)),
         OBJ_TREND,
         0,
         Time[PlateauLength1+PlateauLength2+BreakoutTime+1],
         plateau1.m * 0 + plateau1.b,
         Time[PlateauLength2+BreakoutTime+1],
         plateau1.m * 19 + plateau1.b
         )) {
      Print(__FUNCTION__,
         ": failed to create a trend line! Error code = ",GetLastError());
   } else {
      ObjectSetInteger(0,
         StringConcatenate(lineName1, IntegerToString(count)),
         OBJPROP_RAY_RIGHT,
         0
      );
   }   
   
   if(LogLevel >= LevelDebug)
      PrintFormat("Plateau2: m=%f b=%f r=%f", plateau2.m, plateau2.b, plateau2.r);
   if(!ObjectCreate(0,
         StringConcatenate(lineName2, IntegerToString(count)),
         OBJ_TREND,
         0,
         Time[PlateauLength2],
         plateau2.m * 0 + plateau2.b,
         Time[1],
         plateau2.m * PlateauLength2 + plateau2.b
         )) {
      Print(__FUNCTION__,
         ": failed to create a trend line! Error code = ",GetLastError());
   } else {
      ObjectSetInteger(0,
         StringConcatenate(lineName2, IntegerToString(count)),
         OBJPROP_RAY_RIGHT,
         0
      );
   }
   
   count++;
}
