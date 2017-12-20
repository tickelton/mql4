//+------------------------------------------------------------------+
//|                                                    ttnCommon.mqh |
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

extern int MagicNumber = ttnMagicNumber201703breakoutreversal;
extern eLogLevel LogLevel = LevelError;

int ticketNr = 0;

datetime cond1Time;
double cond2Level = 0;
double cond1Base = 0;
bool cond2Bull = false;
double trailingSL = 0;

double lineM = 0;
double lineB = 0;

const string eaName = "ttn-201703-breakout_reversal";
datetime CurrentTimestamp;

int OnInit()
{
   CurrentTimestamp = Time[0];

   
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
      MqlDateTime timeStr;
      TimeToStruct(CurrentTimestamp, timeStr);
      
      if(ticketNr == 0) {
         if(timeStr.hour >= 7 && timeStr.hour <=16) {
            if(cond2Level == 0) {
               CheckCondition1();
            } else {
               CheckCondition2();
            }
         }
      } else {
         CheckExit();
      }
   }
   
   
}

void CheckCondition1()
{
   double lowCur = Close[1];
   double highCur = Close[1];
   double low1 = Close[6];
   double high1 = Close[6];
   double low2 = Close[21];
   double high2 = Close[21];
   
   for(int i=2; i<6; i++) {
      if(Close[i] < lowCur) {
         lowCur = Close[i];
      }
      if(Close[i] > highCur) {
         highCur = Close[i];
      }
   }
   for(int i=1; i<15; i++) {
      if(Close[6+i] < low1) {
         low1 = Close[6+i];
      }
      if(Close[21+i] < low2) {
         low2 = Close[21+i];
      }
      if(Close[6+i] > high1) {
         high1 = Close[6+i];
      }
      if(Close[21+i] > high2) {
         high2 = Close[21+i];
      }
   }
   
   double rangeCur = highCur - lowCur;
   
   double range1 = high1 - low1;
   double range2 = high2 - low2;
   double rangeAvg = (range1 + range2)/2.0;
   
   linereg(36, 6);
   
   bool bullishCur = false;
   bool bullish1 = false;
   if(Close[1] > Close[5]) {
      bullishCur = true;
   }
   if(lineM > 0) {
      bullish1 = true;
   }

   
   if(lineM != 0.0 && lineM < 0.00001 && lineM > -0.00001 && bullish1 == bullishCur) {
      if(rangeCur > (rangeAvg * 3.0)) {
         cond1Time = CurrentTimestamp;
         if(bullishCur == true) {
            cond2Bull = true;
            cond2Level = lowCur + (rangeAvg * 2.0);
            cond1Base = lowCur;
         } else {
            cond2Bull = false;
            cond2Level = highCur - (rangeAvg * 2.0);
            cond1Base = highCur;
         }
      }
   }
}

void CheckCondition2()
{
   int timeDiff = getTimeDiff(cond1Time);
   
   if(timeDiff >= 5) {
      cond2Level = 0;
      return;
   }
   
   double tmpMA = iMA(NULL, 0, 5, 0, MODE_SMA, PRICE_CLOSE, 1);
   
   int orderOP;
   double orderPrice;
   double stopLoss;
   double marketStopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL) * Point;

   
   if(cond2Bull == true) {
      orderOP = OP_SELL;
      orderPrice = Bid;
      stopLoss = NormalizeDouble(Bid + ((Bid - cond1Base) / 2), Digits);
      if(Bid < cond2Level) {
         cond2Level = 0;
         return;
      }
      if(tmpMA < Bid) {
         return;
      }
   } else {
      orderOP = OP_BUY;
      orderPrice = Ask;
      stopLoss = NormalizeDouble(Ask - ((cond1Base - Ask) / 2), Digits);
      if(Bid > cond2Level) {
         cond2Level = 0;
         return;
      }
      if(tmpMA > Bid) {
         return;
      }
   }
   
   ticketNr = OrderSend(
            Symbol(),
            orderOP,
            1.0,
            orderPrice,
            3,
            0,
            0,
            eaName,
            MagicNumber,
            0,
            clrBlue
   );

   if(ticketNr == -1) {
      PrintFormat("EnterPosition: Error opening order: %s",
         ErrorDescription(GetLastError()));
      ticketNr = 0;
   }
   
}

int getTimeDiff(datetime refTime)
{
   int timeDiff = (int)(CurrentTimestamp - refTime);
   int tfCurrent = Period();
   if(tfCurrent == PERIOD_M1) {
      timeDiff = timeDiff / 60;
   } else if(tfCurrent == PERIOD_M5) {
      timeDiff = timeDiff / 300;
   } else if(tfCurrent == PERIOD_M15) {
      timeDiff = timeDiff / 900;
   } else if(tfCurrent == PERIOD_M30) {
      timeDiff = timeDiff / 1800;
   } else if(tfCurrent == PERIOD_H1) {
      timeDiff = timeDiff / 3600;
   } else if(tfCurrent == PERIOD_H4) {
      timeDiff = timeDiff / 14400;
   } else if(tfCurrent == PERIOD_D1) {
      timeDiff = timeDiff / 86400;
   }
   
   return timeDiff;
}

void CheckExit()
{
   OrderSelect(ticketNr, SELECT_BY_TICKET);
   int timeDiff = getTimeDiff(OrderOpenTime());
   int orderType = OrderType();
   
   if(trailingSL != 0) {
      if(orderType == OP_BUY) {
            if(Bid < trailingSL) {
               doClose(Bid, OrderLots());
               return;
            }
         } else {
            if(Bid > trailingSL) {
               doClose(Ask, OrderLots());
               return;
            }
         }
   }
   
   if(timeDiff < 15) {
      if(orderType == OP_BUY) {
         if(Bid >= cond1Base) {
            doClose(Bid, OrderLots());
            return;
         }
      } else {
         if(Bid <= cond1Base) {
            doClose(Ask, OrderLots());
            return;
         }
      }
      
      if(trailingSL == 0) {
         if(orderType == OP_BUY) {
            if(Bid >= cond1Base - ((cond1Base - OrderOpenPrice()) / 2)) {
               trailingSL = Bid - ((cond1Base - OrderOpenPrice()) / 4);
               return;
            }
         } else {
            if(Bid <= cond1Base + ((OrderOpenPrice() - cond1Base) / 2)) {
               trailingSL = Bid + ((OrderOpenPrice() - cond1Base) / 4);
               return;
            }
         }
      } else {    
         if(orderType == OP_BUY) {
            if(Bid >= Bid - ((cond1Base - OrderOpenPrice()) / 4)) {
               trailingSL = Bid - ((cond1Base - OrderOpenPrice()) / 4);
               return;
            }
         } else {
            if(Bid <= Bid + ((OrderOpenPrice() - cond1Base) / 4)) {
               trailingSL = Bid + ((OrderOpenPrice() - cond1Base) / 4);
               return;
            }
         }
      }
   } else if(timeDiff < 30) {
      if(orderType == OP_BUY) {
         if(Bid >= cond1Base - ((cond1Base - OrderOpenPrice()) / 2)) {
            doClose(Bid, OrderLots());
            return;
         }
      } else {
         if(Bid <= cond1Base + ((OrderOpenPrice() - cond1Base) / 2)) {
            doClose(Ask, OrderLots());
            return;
         }
      }
   } else if(timeDiff >= 30) {
      if(orderType == OP_BUY) {
         doClose(Bid, OrderLots());
         return;
      } else {
         doClose(Ask, OrderLots());
         return;
      }
   }
}

void doClose(double price, double lots)
{
   OrderClose(ticketNr, lots, price, 0, clrRed);
   ticketNr = 0;
   trailingSL = 0;
}

void drawTrendline()
{
   linereg(20, 5);


   if(!ObjectCreate(0,"foobar",OBJ_TREND,0,Time[20],lineM * 0 + lineB,Time[5],lineM * 16 + lineB))
     {
      Print(__FUNCTION__,
            ": failed to create a trend line! Error code = ",GetLastError());
     }
   ObjectSetInteger(0,"foobar",OBJPROP_RAY_RIGHT,0);
}

bool linereg(int n, int m)
{
   double count = n - m + 1.0;
   
   lineM = 0;
   lineB = 0;
   
   double sumx = 0;
   double sumx2 = 0;
   double sumxy = 0;
   double sumy = 0;
   double sumy2 = 0;
   
   double j = 0;
   for(int i=n; i>=m; i--) {
      sumx += j;
      sumx2 += j*j;
      sumxy += j * Close[i];
      sumy += Close[i];
      sumy2 += Close[i] * Close[i];
      j++;
   }
   
   double denom = (count * sumx2 - (sumx * sumx));
   if(denom == 0) {
      return false;
   }
   lineM = (count * sumxy - sumx * sumy) / denom;
   lineB = (sumy * sumx2 - sumx * sumxy) / denom;   
   
   return true;
}

