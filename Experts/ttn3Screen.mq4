//+------------------------------------------------------------------+
//|                                                   ttn3Screen.mq4 |
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
#property version   "1.00"
#property strict

#include <stderror.mqh>
#include <stdlib.mqh>

#include <Events.mq4>

extern int MagicNumber = 5131;

extern double EquityPerTrade = 1.0;
extern bool MACDonlyDiverging = true;
extern int MACDFastEMA = 12;
extern int MACDSlowEMA = 26;
extern int MACDSMA = 9;
enum eUseOscillator {
   OscForce = 1,
   OscStoch = 2,
   OscBoth = 3,
};
extern eUseOscillator UseOscillator = OscForce;
extern int OscForcePeriod = 13;
extern int OscStochK = 5;
extern int OscStochD = 3;
extern int OscStochSlow = 3;
extern int OscPeriodMax = 20;
enum eExitSignal {
   ExitMACD = 1,
   ExitOsc = 2,
};
extern eExitSignal ExitSignal = ExitMACD;
extern bool ExitOnSingleOsc = true;
enum eTrailSLMode {
   TrailNoTrail = 1,
   TrailToBreakEven = 2,
   Trail50Pct = 3,
};
extern eTrailSLMode TrailSLMode = TrailToBreakEven;
extern bool TrailSLOnTick = true;
enum eStopSizeMode {
   StopSizePrice,
   StopSizeATR,
   StopSizeBoth,
};
extern eStopSizeMode StopSizeMode = StopSizeBoth;
extern double StopATR = 2.0;
extern int ATRPeriod = 20;
enum eLogLevel {
   LevelCritical = 0,
   LevelError = 1,
   LevelWarning = 2,
   LevelInfo = 3,
   LevelDebug = 4,
   LevelTrace = 5,
};
extern eLogLevel LogLevel = LevelError;

int PositionOpen = 0;
int CurrentTicket = 0;
double StopSize = 0;
bool doEnter = false;
datetime CurrentTimestamp;
enum TradeDirection {
   DirectionInit,
   DirectionBuy,
   DirectionSell,
   DirectionNoTrade,
};
TradeDirection Direction = DirectionInit;
ENUM_TIMEFRAMES TFHigher = PERIOD_CURRENT;
const int DefaultSlippage = 3;
const string eaName = "ttn3Screen";
enum eSignalType {
   SignalEntry,
   SignalExit,
};
enum ePeriodMaxType {
   PeriodLow,
   PeriodHigh,
};


int OnInit()
{
   int tfCurrent = Period();
   
   if(tfCurrent == PERIOD_M1) {
      TFHigher = PERIOD_M5;
   } else if(tfCurrent == PERIOD_M5) {
      TFHigher = PERIOD_M30;
   } else if(tfCurrent == PERIOD_M15) {
      TFHigher = PERIOD_H1;
   } else if(tfCurrent == PERIOD_M30) {
      TFHigher = PERIOD_H4;
   } else if(tfCurrent == PERIOD_H1) {
      TFHigher = PERIOD_D1;
   } else if(tfCurrent == PERIOD_H4) {
      TFHigher = PERIOD_D1;
   } else if(tfCurrent == PERIOD_D1) {
      TFHigher = PERIOD_W1;
   } else {
      PrintFormat("Timeframe %d not supported", tfCurrent);
      return(INIT_FAILED);
   }
   
   if(LogLevel >= LevelDebug) {
      PrintFormat("Init complete tfCurrent=%d tfHigh=%d", tfCurrent, TFHigher);
   }
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{

   
}

void OnTick()
{

   bool NewBar = false;
   
   CheckEvents(MagicNumber);

   if(eventBuyClosed_SL > 0 ||
       eventSellClosed_SL > 0 ||
       eventBuyClosed_TP > 0 ||
       eventSellClosed_TP > 0) {
      PositionOpen = 0;
      CurrentTicket = 0;
      Direction = DirectionInit;
      doEnter = false;
      StopSize = 0;
   }
   
   if(CurrentTimestamp != Time[0]) {
      CurrentTimestamp = Time[0];
      NewBar = true;
   }
   
   if(NewBar) {
      GetDirection();
      GetSignal();
      if(PositionOpen) {
         TrailSL();
      } else if(doEnter) {
         CheckEntry();
      }
   } else {
      if(PositionOpen) {
         if(TrailSLOnTick) {
            TrailSL();
         }
      } else if(doEnter) {
         CheckEntry();
      }
   }
}

void GetDirection()
{
   double maHighPrev = iMACD(NULL, TFHigher, MACDFastEMA, MACDSlowEMA, MACDSMA, PRICE_CLOSE, MODE_MAIN, 2);
   double maHighCur = iMACD(NULL, TFHigher, MACDFastEMA, MACDSlowEMA, MACDSMA, PRICE_CLOSE, MODE_MAIN, 1);
   if(LogLevel >= LevelTrace) {
      PrintFormat("GetDirection: maHighPrev=%f maHighCur=%f prevDirection=%d", maHighPrev, maHighCur, Direction);
   }
   
   if(!PositionOpen) {
      if(maHighCur < maHighPrev) {
         if(MACDonlyDiverging) {
            if(maHighCur < 0.0 ||
                maHighPrev < 0.0) {
               Direction = DirectionNoTrade;
               return;
            }
         }
         Direction = DirectionSell;
         return;
      } else if(maHighCur > maHighPrev) {
         if(MACDonlyDiverging) {
            if(maHighCur > 0.0 ||
                maHighPrev > 0.0) {
               Direction = DirectionNoTrade;
               return;
            }
         }
         Direction = DirectionBuy;
         return;
      } else {
         Direction = DirectionNoTrade;
         return;
      }
   } else if(ExitSignal == ExitMACD){
      if(maHighCur < maHighPrev &&
          Direction == DirectionBuy) {
         ClosePosition();
         return;
      } else if(maHighCur > maHighPrev &&
          Direction == DirectionSell) {
         ClosePosition();
         return;
      } else {
         return;
      }
   } else if(ExitSignal == ExitOsc) {
      return;
   }
   
   Direction = DirectionInit;
}

void GetSignal()
{
   if(Direction == DirectionInit ||
       Direction == DirectionNoTrade) {
      doEnter = false;
      return;
   }

   if(PositionOpen) {
      if(ExitSignal == ExitOsc) {
         if(GetSignal(SignalExit)) {
            ClosePosition();
         }
      }
   } else if(GetSignal(SignalEntry)) {
      doEnter = true;
      return;
   }
   
   doEnter = false;
}

bool GetSignal(eSignalType signalType)
{
   bool signalForce = false;
   bool signalStoch = false;

   if(UseOscillator == OscForce) {
      signalStoch = true;
      signalForce = GetSignalForce(signalType);
   } else if(UseOscillator == OscStoch) {
      signalForce = true;
      signalStoch = GetSignalStoch(signalType);
   } else if(UseOscillator == OscBoth) {
      signalForce = GetSignalForce(signalType);
      signalStoch = GetSignalStoch(signalType);
   } else {
      return false;
   }
   
   if(LogLevel >= LevelTrace) {
      PrintFormat("GetSignal: type=%d signalForce=%d signalStoch=%d", signalType, signalForce, signalStoch);
   }
   
   if(signalType == SignalEntry) {
      if(signalForce && signalStoch) {
         return true;
      }
   } else {
      if(UseOscillator == OscBoth &&
          ExitOnSingleOsc) {
         if(signalForce || signalStoch) {
            return true;
         }
      } else {
         if(signalForce && signalStoch) {
            return true;
         }
      }
   }

   return false;
}

bool GetSignalForce(eSignalType signalType)
{
   double valForce = iForce(NULL, 0, OscForcePeriod, MODE_SMA, PRICE_CLOSE, 1);
   
   if(LogLevel >= LevelTrace) {
      PrintFormat("GetSignalForce: val=%f Direction=%d", valForce, Direction);
   }
   
   if(signalType == SignalEntry) {
      if(Direction == DirectionBuy) {
         double periodLow = GetForcePeriodMax(OscPeriodMax, PeriodLow);
         if(periodLow == -1.0) {
            return false;
         }
         if(valForce < 0.0 &&
             valForce > periodLow) {
            return true;
         }
      } else if(Direction == DirectionSell) {
         double periodHigh = GetForcePeriodMax(OscPeriodMax, PeriodHigh);
         if(periodHigh == -1.0) {
            return false;
         }
         if(valForce > 0.0 &&
             valForce < periodHigh) {
            return true;
         }
      } else {
         return false;
      }
   } else {
      if(Direction == DirectionBuy) {
         if(valForce > 0.0) {
            return true;
         }
      } else if(Direction == DirectionSell) {
         if(valForce < 0.0) {
            return true;
         }
      }
   }
   
   return false;
}

double GetForcePeriodMax(int periodLen, ePeriodMaxType type)
{
   if(type == PeriodHigh) {
      double valForce = iForce(NULL, 0, OscForcePeriod, MODE_SMA, PRICE_CLOSE, 2);
      for(int i=3; i<=periodLen; i++) {
         double valForceTmp = iForce(NULL, 0, OscForcePeriod, MODE_SMA, PRICE_CLOSE, i);
         if(valForceTmp > valForce) {
            valForce = valForceTmp;
         }
      }
      return valForce;
   } else if(type == PeriodLow) {
      double valForce = iForce(NULL, 0, OscForcePeriod, MODE_SMA, PRICE_CLOSE, 2);
      for(int i=3; i<=periodLen; i++) {
         double valForceTmp = iForce(NULL, 0, OscForcePeriod, MODE_SMA, PRICE_CLOSE, i);
         if(valForceTmp < valForce) {
            valForce = valForceTmp;
         }
      }
      return valForce;
   } else {
      return -1.0;
   }
}

bool GetSignalStoch(eSignalType signalType)
{
   double valStoch = iStochastic(NULL, 0, OscStochK, OscStochD, OscStochSlow, MODE_SMA, 0, MODE_MAIN, 1);
 
   if(signalType == SignalEntry) {
      if(Direction == DirectionBuy) {
         double periodLow = GetStochPeriodMax(OscPeriodMax, PeriodLow);
         if(periodLow == -1.0) {
            return false;
         }
         if(valStoch < 30.0 &&
             valStoch > periodLow) {
            return true;
         }
      } else if(Direction == DirectionSell) {
         double periodHigh = GetForcePeriodMax(OscPeriodMax, PeriodHigh);
         if(periodHigh == -1.0) {
            return false;
         }
         if(valStoch > 70.0 &&
             valStoch < periodHigh) {
            return true;
         }
      } else {
         return false;
      }
   } else {
      if(Direction == DirectionBuy) {
         if(valStoch > 30.0) {
            return true;
         }
      } else if(Direction == DirectionSell) {
         if(valStoch < 70.0) {
            return true;
         }
      }
   }
   
   return false;
}

double GetStochPeriodMax(int periodLen, ePeriodMaxType type)
{
   if(type == PeriodHigh) {
      double valStoch = iStochastic(NULL, 0, OscStochK, OscStochD, OscStochSlow, MODE_SMA, 0, MODE_MAIN, 2);
      for(int i=3; i<=periodLen; i++) {
         double valStochTmp = iStochastic(NULL, 0, OscStochK, OscStochD, OscStochSlow, MODE_SMA, 0, MODE_MAIN, i);
         if(valStochTmp > valStoch) {
            valStoch = valStochTmp;
         }
      }
      return valStoch;
   } else if(type == PeriodLow) {
      double valStoch = iStochastic(NULL, 0, OscStochK, OscStochD, OscStochSlow, MODE_SMA, 0, MODE_MAIN, 2);
      for(int i=3; i<=periodLen; i++) {
         double valStochTmp = iStochastic(NULL, 0, OscStochK, OscStochD, OscStochSlow, MODE_SMA, 0, MODE_MAIN, i);
         if(valStochTmp < valStoch) {
            valStoch = valStochTmp;
         }
      }
      return valStoch;
   } else {
      return -1.0;
   }
}

void CheckEntry() {
   if(Direction == DirectionBuy) {
      double prevHigh = High[1];
      if(Bid >= prevHigh + Point) {
         OpenPosition();
      }
   } else if(Direction == DirectionSell) {
      double prevLow = Low[1];
      if(Bid <= prevLow - Point) {
         OpenPosition();
      }
   }
}

void ClosePosition()
{
   if(CurrentTicket == 0) {
      Print("Fatal: cannot close; no current order");
   }
   
   if(OrderSelect(CurrentTicket, SELECT_BY_TICKET) != true) {
      Print("Fatal: cannot select current order");
   }
   
   bool closeRet = false;
   if(Direction == DirectionBuy) {
      closeRet = OrderClose(CurrentTicket, OrderLots(), Bid, DefaultSlippage, clrRed);
   } else if(Direction == DirectionSell) {
      closeRet = OrderClose(CurrentTicket, OrderLots(), Ask, DefaultSlippage, clrBlue);
   }

   if(closeRet != true) {
      Print("Fatal: cannot close current order");
      return;
   }
   
   PositionOpen = 0;
   CurrentTicket = 0;
   Direction = DirectionInit;
   doEnter = false;
   StopSize = 0;
   return;
}

void OpenPosition()
{
   double stopLevel = -1;
   if(Direction == DirectionBuy) {
      stopLevel = getStopLevel(Ask);
   } else if(Direction == DirectionSell) {
      stopLevel = getStopLevel(Bid);
   }

   if(stopLevel < 0) {
      if(LogLevel >= LevelError) {
         PrintFormat("OpenPosition: Error stopLevel.");
      }
      return;
   }
   
   double stopSize;
   if(Direction == DirectionBuy) {
      stopSize = (Ask - stopLevel) / Point;
      if(Point == 0.001 || Point == 0.00001) stopSize /= 10;
   } else if(Direction == DirectionSell) {
      stopSize = (stopLevel - Bid) / Point;
      if(Point == 0.001 || Point == 0.00001) stopSize /= 10;
   } else {
      if(LogLevel >= LevelError) {
         PrintFormat("OpenPosition: Error Direction.");
      }
      return;
   }
   double lotSize = getLotSize(stopSize);
   if(lotSize < 0) {
      if(LogLevel >= LevelError) {
         PrintFormat("OpenPosition: Error lotSize.");
      }
      return;
   }
   
   int ticketNr = -1;
   if(Direction == DirectionBuy) {
      ticketNr = OrderSend(Symbol(), OP_BUY, lotSize, Ask, DefaultSlippage, stopLevel, 0, "ttn3Screen Long", MagicNumber, 0, clrBlue);
   } else if(Direction == DirectionSell) {
      ticketNr = OrderSend(Symbol(), OP_SELL, lotSize, Bid, DefaultSlippage, stopLevel, 0, "ttn3Screen Short", MagicNumber, 0, clrRed);
   } else {
      return;
   }
   
   if(ticketNr != -1) {
      PositionOpen = 1;
      CurrentTicket = ticketNr;
      StopSize = stopSize * Point;
      if(LogLevel >= LevelDebug) {
         PrintFormat("TRADE: dir=%d stop=%f lotsize=%f ticket=%d", Direction, stopLevel, lotSize, ticketNr);
      }
   }
   
   CheckEvents(MagicNumber);
   if(eventBuyClosed_SL > 0 ||
       eventSellClosed_SL > 0 ||
       eventBuyClosed_TP > 0 ||
       eventSellClosed_TP > 0) {
      PositionOpen = 0;
      CurrentTicket = 0;
      Direction = DirectionInit;
      doEnter = false;
      StopSize = 0;
   }
}

double getStopLevel(double currentPrice)
{
   double level = 1.0;
   double marketStopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL) * Point;
   
   
   if(StopSizeMode == StopSizePrice) {
      if(Direction == DirectionBuy) {
         double curLow = Low[0];
         double prevLow = Low[1];
         if(curLow < prevLow) {
            level = curLow - Point;    
         } else {
            level = prevLow - Point;
         }
         if(level > Ask - marketStopLevel) {
            PrintFormat("SL(%f) > Ask(%f) - minSL(%f)", level, Ask, marketStopLevel);
            return -1.0;
         }
      } else if (Direction == DirectionSell) {
         double curHigh = High[0];
         double prevHigh = High[1];
         if(curHigh > prevHigh) {
            level = curHigh + Point;    
         } else {
            level = prevHigh + Point;
         }
         if(level < Bid + marketStopLevel) {
            PrintFormat("SL(%f) < Bid(%f) + minSL(%f)", level, Bid, marketStopLevel);
            return -1.0;
         }
      } else {
         return -1.0;
      }
   } else if(StopSizeMode == StopSizeATR) {
      double curATR = iATR(NULL, 0, ATRPeriod, 1);
      if(curATR == 0.0) {
         if(LogLevel >= LevelError) {
            PrintFormat("Error: ATR=%f", curATR);
         }
         return -1.0;
      }
      
      if(Direction == DirectionBuy) {
         level = Bid - (StopATR * curATR);
         if(level > Ask - marketStopLevel) {
            PrintFormat("SL(%f) > Ask(%f) - minSL(%f)", level, Ask, marketStopLevel);
            return -1.0;
         }
         return level;
      } else if(Direction == DirectionSell) {
         level = Ask + (StopATR * curATR);
         if(level < Bid + marketStopLevel) {
            PrintFormat("SL(%f) < Bid(%f) + minSL(%f)", level, Bid, marketStopLevel);
            return -1.0;
         }
         return level;
      } else {
         if(LogLevel >= LevelError) {
            PrintFormat("Error: GetStopSize: Direction=%d", Direction);
         }
         return -1.0;
      }
   } else if(StopSizeMode == StopSizeBoth) {
      double curATR = iATR(NULL, 0, ATRPeriod, 1);
      if(curATR == 0.0) {
         if(LogLevel >= LevelError) {
            PrintFormat("Error: ATR=%f", curATR);
         }
         return -1.0;
      }
      
      if(Direction == DirectionBuy) {
         double curLow = Low[0];
         double prevLow = Low[1];
         double levelPrice;
         double levelATR;
         if(curLow < prevLow) {
            levelPrice = curLow - Point;    
         } else {
            levelPrice = prevLow - Point;
         }
         levelATR = Bid - (StopATR * curATR);
         if(levelATR < levelPrice) {
            level = levelATR;
         } else {
            level = levelPrice;
         }
         if(level > Ask - marketStopLevel) {
            PrintFormat("SL(%f) > Ask(%f) - minSL(%f)", level, Ask, marketStopLevel);
            return -1.0;
         }
      } else if (Direction == DirectionSell) {
         double curHigh = High[0];
         double prevHigh = High[1];
         double levelPrice;
         double levelATR;
         if(curHigh > prevHigh) {
            levelPrice = curHigh + Point;    
         } else {
            levelPrice = prevHigh + Point;
         }
         levelATR = Ask + (StopATR * curATR);
         if(levelATR > levelPrice) {
            level = levelATR;
         } else {
            level = levelPrice;
         }
         if(level < Bid + marketStopLevel) {
            PrintFormat("SL(%f) < Bid(%f) + minSL(%f)", level, Bid, marketStopLevel);
            return -1.0;
         }
      } else {
         return -1.0;
      }
   }
   
   return level;
}

double getLotSize(double stopSize)
{
   double riskAmount = AccountEquity() * (EquityPerTrade / 100);

   double tickValue = MarketInfo(Symbol(),MODE_TICKVALUE);
   if(Point == 0.001 || Point == 0.00001) tickValue *= 10;
   
   double lotSize = (riskAmount / stopSize) / tickValue;
   
   if(lotSize < MarketInfo(Symbol(),MODE_MINLOT))
   {
      return -1.0;
   } else if(lotSize > MarketInfo(Symbol(),MODE_MAXLOT))
   {
      lotSize = MarketInfo(Symbol(),MODE_MAXLOT);
   }
   
   if(MarketInfo(Symbol(),MODE_LOTSTEP) == 0.1)
   {
      lotSize = NormalizeDouble(lotSize,1);
   }
   else {
      lotSize = NormalizeDouble(lotSize,2);
   }

   return lotSize;
}

void TrailSL()
{
   if(TrailSLMode == TrailNoTrail) {
      return;
   } else if(TrailSLMode == TrailToBreakEven) {
      double trailPrice;
      if(TrailSLOnTick) {
         trailPrice = Close[0];
      } else {
         trailPrice = Close[1];
      }
      if(OrderSelect(CurrentTicket, SELECT_BY_TICKET)) {
         double orderOpenPrice = OrderOpenPrice();
         double orderStopLoss = OrderStopLoss();
         double currentStopDistance;
     
         if(orderStopLoss >= orderOpenPrice) {
            return;
         }
         
         if(Direction == DirectionBuy) {
            currentStopDistance = trailPrice - orderStopLoss;
         } else if(Direction == DirectionSell) {
            currentStopDistance = orderStopLoss - trailPrice;
         } else {
            return;
         }
         
         if(StopSize > 0 &&
             currentStopDistance > StopSize) {
            
            double newStopLoss;
            if(Direction == DirectionBuy) {
               newStopLoss = trailPrice - StopSize;
               if(newStopLoss > (orderOpenPrice + (Ask - Bid)))
                  newStopLoss = orderOpenPrice + (Ask - Bid);
            } else if(Direction == DirectionSell) {
               newStopLoss = trailPrice + StopSize;
               if(newStopLoss < (orderOpenPrice - (Bid - Ask)))
                  newStopLoss = orderOpenPrice - (Bid - Ask);
            } else {
               return;
            }
            
            double marketStopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL) * Point;
            
            if(Direction == DirectionBuy) {
               if(newStopLoss > Bid - marketStopLevel) {
                  if(Bid - marketStopLevel > orderStopLoss) {
                     PrintFormat("%f > Bid(%f) - minSL(%f); setting new Sl to %f",
                        newStopLoss, Bid, marketStopLevel, Bid - marketStopLevel);
                     newStopLoss = Bid - marketStopLevel;
                  }
               }
               if(newStopLoss < orderStopLoss) {
                  Print("new SL would be < current SL; aborting");
                  return;
               }
            } else if(Direction == DirectionSell) {
               if(newStopLoss < Ask + marketStopLevel) {
                  if(Ask + marketStopLevel < orderStopLoss) {
                     PrintFormat("%f < Ask(%f) + minSL(%f); setting new Sl to %f",
                        newStopLoss, Ask, marketStopLevel, Ask + marketStopLevel);
                     newStopLoss = Ask + marketStopLevel;
                  }
               } 
               if(newStopLoss > orderStopLoss) {
                  Print("new SL would be > current SL; aborting");
                  return;
               }       
            }
   
            if(!OrderModify(CurrentTicket, OrderOpenPrice(), NormalizeDouble(newStopLoss, Digits), OrderTakeProfit(), 0, clrYellow)) {
               Print("Warning: error trailing SL ", ErrorDescription(GetLastError()));
               return;
            }
         }
      }  else {
         if(LogLevel >= LevelError) {
            Print("TrailSL Error: Cannot select order: ",GetLastError());
            return;
         }
      }
   } else if(TrailSLMode == Trail50Pct) {
      double trailPrice;
      if(TrailSLOnTick) {
         trailPrice = Close[0];
      } else {
         trailPrice = Close[1];
      }
      if(OrderSelect(CurrentTicket, SELECT_BY_TICKET)) {
         double orderOpenPrice = OrderOpenPrice();
         double orderStopLoss = OrderStopLoss();
         double currentStopDistance;
      
         if(orderStopLoss >= orderOpenPrice) {
            return;
         }
         
         if(Direction == DirectionBuy) {
            currentStopDistance = trailPrice - orderStopLoss;
         } else if(Direction == DirectionSell) {
            currentStopDistance = orderStopLoss - trailPrice;
         } else {
            return;
         }
         
         if(StopSize > 0 &&
             currentStopDistance > StopSize) {
            
            double newStopLoss;
            if(Direction == DirectionBuy) {
               newStopLoss = trailPrice - StopSize;
               if(newStopLoss > (orderOpenPrice + (Ask - Bid)))
                  newStopLoss = trailPrice - ((trailPrice - orderOpenPrice) / 2.0);
            } else if(Direction == DirectionSell) {
               newStopLoss = trailPrice + StopSize;
               if(newStopLoss < (orderOpenPrice - (Bid - Ask)))
                  newStopLoss = trailPrice + ((orderOpenPrice - trailPrice) / 2.0);
            } else {
               return;
            }
            
            double marketStopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL) * Point;
            
            if(Direction == DirectionBuy) {
               if(newStopLoss > Bid - marketStopLevel) {
                  if(Bid - marketStopLevel > orderStopLoss) {
                     PrintFormat("%f > Bid(%f) - minSL(%f); setting new Sl to %f",
                        newStopLoss, Bid, marketStopLevel, Bid - marketStopLevel);
                     newStopLoss = Bid - marketStopLevel;
                  }
               }
               if(newStopLoss < orderStopLoss) {
                  Print("new SL would be < current SL; aborting");
                  return;
               }
            } else if(Direction == DirectionSell) {
               if(newStopLoss < Ask + marketStopLevel) {
                  if(Ask + marketStopLevel < orderStopLoss) {
                     PrintFormat("%f < Ask(%f) + minSL(%f); setting new Sl to %f",
                        newStopLoss, Ask, marketStopLevel, Ask + marketStopLevel);
                     newStopLoss = Ask + marketStopLevel;
                  }
               } 
               if(newStopLoss > orderStopLoss) {
                  Print("new SL would be > current SL; aborting");
                  return;
               }       
            }
   
            if(!OrderModify(CurrentTicket, OrderOpenPrice(), NormalizeDouble(newStopLoss, Digits), OrderTakeProfit(), 0, clrYellow)) {
               Print("Warning: error trailing SL ", ErrorDescription(GetLastError()));
               return;
            }
         }
      }  else {
         if(LogLevel >= LevelError) {
            Print("TrailSL Error: Cannot select order: ",GetLastError());
            return;
         }
      }
   }

   return;
}
