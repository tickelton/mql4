//+------------------------------------------------------------------+
//|                                                ttnTrendRider.mq4 |
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
#include <Events.mq4>

#property copyright "tickelton@gmail.com"
#property link      "https://github.com/tickelton"
#property version   "1.00"
#property strict

extern int MagicNumber = 5124;
extern int LongTermMAPeriod = 288;
extern int SlowMAPeriod = 14;
extern int IntermediateMAPeriod = 6;
extern int FastMAPeriod = 4;
extern int MAlevelFlipPeriod = 4;
extern int ADXperiod = 14;
extern double MinADX = 25;
extern double FactorReversalCandle = 1.5;
extern double EquityPerTrade = 1.0;
/*
   Log Levels:
   0 = Critical
   1 = Error
   2 = Warning
   3 = Info
   4 = Debug
*/
extern int LogLevel = 0;

enum TradeDirection {
   DirectionInit,
   DirectionBuy,
   DirectionSell,
   DirectionNoTrade,
};

enum CandleType {
   CandleBearish,
   CandleBullish,
};

int PositionOpen = 0;
int CurrentTicket = 0;
datetime CurrentTimestamp;
TradeDirection direction = DirectionInit;
int DefaultSlippage = 3;

int OnInit()
{
   CurrentTimestamp = Time[0];

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
   }
   
   if(CurrentTimestamp != Time[0]) {
      CurrentTimestamp = Time[0];
      NewBar = true;
   }
   
   if(NewBar) {
      if(PositionOpen) {
         // In a position.
         if(direction == DirectionBuy) {
            double sellBelow = iMA(NULL, 0, SlowMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, 0);
            if(Close[1] < sellBelow) {
               bool closeRet = CloseCurrentOrder();
            } else {
               // If we still are in a Position, check if we need to trail the SL.
               if(!TrailStopLossMAlow()) {
                     if(LogLevel < 3) {
                        Print("Warning: error trailing bull SL");
                     }
               }
            }
         } else if(direction == DirectionSell) {
            double sellAbove = iMA(NULL, 0, SlowMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, 0);
            if(Close[1] > sellAbove) {
               bool closeRet = CloseCurrentOrder();
            } else {
               // If we still are in a Position, check if we need to trail the SL.
               if(!TrailStopLossMAlow()) {
                  if(LogLevel < 3) {
                     Print("Warning: error trailing bear SL");
                  }
               }
            }
         }
      } else {
         // Not in a position.
         if(checkMAlevels()) {
            if(direction == DirectionBuy ||
                direction == DirectionSell) {
               if(checkSignalCandle()) {
                  if(checkMACD()){
                     if(checkADX()) {         
                        if(PlaceOrder() != true) {
                           if(LogLevel < 2) {
                              Print("Error placing sell order");
                           }
                        }
                     }
                  }
               }
            }
         }
      }   
   }
}

bool checkMAlevels()
{
   TradeDirection tmpDirection = DirectionNoTrade;
   double fastMAlevel = iMA(NULL, 0, FastMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, 0);
   double intermediateMAlevel = iMA(NULL, 0, IntermediateMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, 0);
   double slowMAlevel = iMA(NULL, 0, SlowMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, 0);
   
   if(fastMAlevel > intermediateMAlevel &&
       intermediateMAlevel > slowMAlevel &&
       fastMAlevel > slowMAlevel) {
      for(int i=1; i<=MAlevelFlipPeriod; i++) {
         double prevFastMAlevel = iMA(NULL, 0, FastMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, i);
         double prevIntermediateMAlevel = iMA(NULL, 0, IntermediateMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, i);
         double prevSlowMAlevel = iMA(NULL, 0, SlowMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, i);
         if(prevFastMAlevel > prevIntermediateMAlevel &&
             prevIntermediateMAlevel > prevSlowMAlevel &&
             prevFastMAlevel > prevSlowMAlevel) {
             tmpDirection = DirectionNoTrade;
             break;
         }
         if(prevFastMAlevel < prevIntermediateMAlevel &&
             prevIntermediateMAlevel < prevSlowMAlevel &&
             prevFastMAlevel < prevSlowMAlevel) {
             tmpDirection = DirectionBuy;
             break;
         }
      }
   
   } else if(fastMAlevel < intermediateMAlevel &&
              intermediateMAlevel < slowMAlevel &&
              fastMAlevel < slowMAlevel) {
      for(int i=1; i<=MAlevelFlipPeriod; i++) {
         double prevFastMAlevel = iMA(NULL, 0, FastMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, i);
         double prevIntermediateMAlevel = iMA(NULL, 0, IntermediateMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, i);
         double prevSlowMAlevel = iMA(NULL, 0, SlowMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, i);
         if(prevFastMAlevel < prevIntermediateMAlevel &&
             prevIntermediateMAlevel < prevSlowMAlevel &&
             prevFastMAlevel < prevSlowMAlevel) {
             tmpDirection = DirectionNoTrade;
             break;
         }
         if(prevFastMAlevel > prevIntermediateMAlevel &&
             prevIntermediateMAlevel > prevSlowMAlevel &&
             prevFastMAlevel > prevSlowMAlevel) {
             tmpDirection = DirectionSell;
             break;
         }
      }
   }
   
   if(tmpDirection == DirectionBuy ||
       tmpDirection == DirectionSell) {
      direction = tmpDirection;
      return true;
   }
   
   direction = tmpDirection;
   return false;
}

bool checkSignalCandle()
{
   double prevLongTermMAlevel = iMA(NULL, 0, LongTermMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, 1);
   double curLongTermMAlevel = iMA(NULL, 0, LongTermMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, 0);
   double slowMAlevel = iMA(NULL, 0, SlowMAPeriod, 1, MODE_EMA, PRICE_TYPICAL, 0);
   double priceOpen = Open[1];
   
   if(direction == DirectionBuy) {
      if(CandleIsDecisive(CandleBullish, 1)){
         if(priceOpen > slowMAlevel &&
             priceOpen > curLongTermMAlevel) {
            return true;
         }
      }
   } else if(direction == DirectionSell) {
      if(CandleIsDecisive(CandleBearish, 1)) {
         if(priceOpen < slowMAlevel &&
             priceOpen < curLongTermMAlevel) {
            return true;
         }
      }
   }
   
   return false;
}

bool CandleIsDecisive(CandleType type, int idx)
{
   if(type == CandleBearish) {
      if(Close[idx] > Open[idx])
         return false;
         
      double candleHeight = Open[idx] - Close[idx];
      
      if(Point == 0.0001 || Point == 0.00001){
         if (candleHeight < 0.0001) {
            return false;
         }
      } else if(Point == 0.01 || Point == 0.001) {
         if (candleHeight < 0.01) {
            return false;
         }
      }
      double wickTop = High[idx] - Open[idx];
      double wickBottom = Close[idx] - Low[idx];
      
      if(wickTop > (candleHeight * FactorReversalCandle))
         return false;
      if(wickBottom > (candleHeight * FactorReversalCandle))
         return false;
      
      return true;
   } else if (type == CandleBullish) {
      if(Open[idx] > Close[idx])
         return false;
         
      double candleHeight = Close[idx] - Open[idx];
      if(Point == 0.0001 || Point == 0.00001){
         if (candleHeight < 0.0001) {
            return false;
         }
      } else if(Point == 0.01 || Point == 0.001) {
         if (candleHeight < 0.01) {
            return false;
         }
      }
      
      double wickTop = High[idx] - Close[idx];
      double wickBottom = Open[idx] - Low[idx];
      
      if(wickTop > (candleHeight * FactorReversalCandle))
         return false;
      if(wickBottom > (candleHeight * FactorReversalCandle))
         return false;
         
      return true;
   }

   return false;
}

bool checkMACD()
{
   double prevMACD = iMACD(NULL,0,IntermediateMAPeriod,SlowMAPeriod,FastMAPeriod,PRICE_CLOSE,MODE_MAIN,2);
   double nowMACD = iMACD(NULL,0,IntermediateMAPeriod,SlowMAPeriod,FastMAPeriod,PRICE_CLOSE,MODE_MAIN,1);
   double prevMACDsignal = iMACD(NULL,0,IntermediateMAPeriod,SlowMAPeriod,FastMAPeriod,PRICE_CLOSE,MODE_SIGNAL,2);
   double nowMACDsignal = iMACD(NULL,0,IntermediateMAPeriod,SlowMAPeriod,FastMAPeriod,PRICE_CLOSE,MODE_SIGNAL,1);

   if(direction == DirectionBuy) {
      if((prevMACD < 0 && nowMACD >= 0) ||
          (prevMACD <= 0 && nowMACD > 0)) {
         return true;
      }
   } else if(direction == DirectionSell) {
      if((prevMACD > 0 && nowMACD <= 0) ||
          (prevMACD >= 0 && nowMACD < 0)) {
         return true;
      }
   }
   
   return false;
}

bool checkADX()
{
   double prevADX = iADX(NULL, 0, ADXperiod, PRICE_TYPICAL, MODE_MAIN, 2);
   double nowADX = iADX(NULL, 0, ADXperiod, PRICE_TYPICAL, MODE_MAIN, 1);
   
   if(nowADX >= MinADX) {
      return true;
   }
   
   return false;
}

bool TrailStopLossMAlow()
{
   if(OrderSelect(CurrentTicket, SELECT_BY_TICKET)) {
      double orderStopLoss = OrderStopLoss();
      double orderOpenPrice = OrderOpenPrice();
      
      double newStopLoss = 0;
      if(direction == DirectionBuy) {
         double maLevel = iMA(NULL, 0, SlowMAPeriod, 1, MODE_EMA, PRICE_LOW, 0);
         if(maLevel > orderStopLoss)
            newStopLoss = maLevel;
      } else if(direction == DirectionSell) {
         double maLevel = iMA(NULL, 0, SlowMAPeriod, 1, MODE_EMA, PRICE_HIGH, 0);
         if(maLevel < orderStopLoss)
            newStopLoss = maLevel;
      } else {
         return false;
      }
            
      if(newStopLoss != 0) {
         if(direction == DirectionBuy) {
            if(newStopLoss > (orderOpenPrice + (Ask - Bid)))
               newStopLoss = orderOpenPrice + (Ask - Bid);
         } else if(direction == DirectionSell) {
            if(newStopLoss < (orderOpenPrice - (Bid - Ask)))
               newStopLoss = orderOpenPrice - (Bid - Ask);
         } else {
            return false;
         }
         
         double marketStopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL) * Point;
         
         if(direction == DirectionBuy) {
            if(newStopLoss > Bid - marketStopLevel) {
               if(Bid - marketStopLevel > orderStopLoss) {
                  if(LogLevel < 4) {
                     PrintFormat("%f > Bid(%f) - minSL(%f); setting new Sl to %f",
                        newStopLoss, Bid, marketStopLevel, Bid - marketStopLevel);
                  }
                  newStopLoss = Bid - marketStopLevel;
               }
            }
            if(newStopLoss < orderStopLoss) {
               if(LogLevel < 4) {
                  Print("new SL would be < current SL; aborting");
               }
               return false;
            }
         } else if(direction == DirectionSell) {
            if(newStopLoss < Ask + marketStopLevel) {
               if(Ask + marketStopLevel < orderStopLoss) {
                  if(LogLevel < 4) {
                     PrintFormat("%f < Ask(%f) + minSL(%f); setting new Sl to %f",
                        newStopLoss, Ask, marketStopLevel, Ask + marketStopLevel);
                  }
                  newStopLoss = Ask + marketStopLevel;
               }
            } 
            if(newStopLoss > orderStopLoss) {
               if(LogLevel < 4) {
                  Print("new SL would be > current SL; aborting");
               }
               return false;
            }       
         }

         if(!OrderModify(CurrentTicket, OrderOpenPrice(), NormalizeDouble(newStopLoss, Digits), OrderTakeProfit(), 0, clrYellow)) {
            if(LogLevel < 3) {
               Print("Warning: error trailing SL ", GetLastError());
            }
            return false;
         }
      }
   } else {
      if(LogLevel < 3) {
         Print("Warning: Cannot select order: ",GetLastError());
      }
      return false;
   }
   
   return true;
}

bool CloseCurrentOrder()
{
   if(CurrentTicket == 0) {
      if(LogLevel <= 0) {
         Print("Fatal: cannot close; no current order");
      }
   }
   
   if(OrderSelect(CurrentTicket, SELECT_BY_TICKET) != true) {
      if(LogLevel <= 0) {
         Print("Fatal: cannot select current order");
      }
   }
   
   bool closeRet = false;
   if(direction == DirectionBuy) {
      closeRet = OrderClose(CurrentTicket, OrderLots(), Bid, DefaultSlippage, clrRed);
   } else if(direction == DirectionSell) {
      closeRet = OrderClose(CurrentTicket, OrderLots(), Ask, DefaultSlippage, clrBlue);
   }

   if(closeRet != true) {
      if(LogLevel <= 0) {
         Print("Fatal: cannot close current order");
      }
      return false;
   }
   
   PositionOpen = 0;
   CurrentTicket = 0;
   
   return true;
}

bool PlaceOrder()
{
   double stopLevel = -1;
   if(direction == DirectionBuy) {
      stopLevel = getStopLevel(Ask);
   } else if(direction == DirectionSell) {
      stopLevel = getStopLevel(Bid);
   }
   
   if(stopLevel < 0)
      return false;
   
   double stopSize;
   if(direction == DirectionBuy) {
      stopSize = (Ask - stopLevel) / Point;
      if(Point == 0.001 || Point == 0.00001) stopSize /= 10;
   } else if(direction == DirectionSell) {
      stopSize = (stopLevel - Bid) / Point;
      if(Point == 0.001 || Point == 0.00001) stopSize /= 10;
   } else {
      return false;
   }
   double lotSize = getLotSize(stopSize);
   if(lotSize < 0)
      return false;

   int ticketNr = -1;
   if(direction == DirectionBuy) {
         ticketNr = OrderSend(Symbol(), OP_BUY, lotSize, Ask, DefaultSlippage, stopLevel, 0, "ttnTrendRider Long", MagicNumber, 0, clrBlue);
   } else if(direction == DirectionSell) {
         ticketNr = OrderSend(Symbol(), OP_SELL, lotSize, Bid, DefaultSlippage, stopLevel, 0, "ttnTrendRider Short", MagicNumber, 0, clrRed);
   } else {
      return false;
   }
   
   if(ticketNr != -1) {
      PositionOpen = 1;
      CurrentTicket = ticketNr;
      if(LogLevel < 5) {
         PrintFormat("TRADE: dir=%d stop=%f lotsize=%f ticket=%d", direction, stopLevel, lotSize, ticketNr);
      }
   }
   
   CheckEvents(MagicNumber);
   if(eventBuyClosed_SL > 0 ||
       eventSellClosed_SL > 0 ||
       eventBuyClosed_TP > 0 ||
       eventSellClosed_TP > 0) {
      PositionOpen = 0;
   }
   
   return true;
}

double getStopLevel(double currentPrice)
{
   double level;
   double marketStopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL) * Point;
   
   if(direction == DirectionBuy) {
      level = iMA(NULL, 0, SlowMAPeriod, 1, MODE_EMA, PRICE_LOW, 0);
      if(level > Bid - marketStopLevel) {
         if(LogLevel < 4) {
            PrintFormat("SL(%f) > Bid(%f) - minSL(%f)", level, Bid, marketStopLevel);
         }
         return Bid - marketStopLevel;
      }
   } else if (direction == DirectionSell) {
      level = iMA(NULL, 0, FastMAPeriod, 1, MODE_EMA, PRICE_HIGH, 0);
      if(level < Ask + marketStopLevel) {
         if(LogLevel < 4) {
            PrintFormat("SL(%f) < Ask(%f) + minSL(%f)", level, Ask, marketStopLevel);
         }
         return Ask + marketStopLevel;
      }
   } else {
      return -1.0;
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
