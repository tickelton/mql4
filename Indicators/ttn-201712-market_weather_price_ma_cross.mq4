//+------------------------------------------------------------------+
//|                     ttn-201712-market_weather_price_ma_cross.mq4 |
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

#property indicator_separate_window
#property indicator_buffers    1
#property indicator_color1     Gold

input int MAperiod = 60;
input int CountPeriods = 180;

double ExtCrossBuffer[];
double ExtMABuffer[];

int OnInit(void)
{
   string short_name;
   
   IndicatorBuffers(2);
   IndicatorDigits(Digits);
   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID, 1);
   SetIndexBuffer(0, ExtCrossBuffer);
   SetIndexBuffer(1, ExtMABuffer);
   
   short_name="MWPMC("+
         IntegerToString(MAperiod)+"/"+
         IntegerToString(CountPeriods)+")";
   IndicatorShortName(short_name);
   SetIndexLabel(0,short_name);

   SetIndexDrawBegin(0,0);

   return(INIT_SUCCEEDED);
}

int getCrossValue(int idx)
{
   static bool once = true;
   int crossCount = 0;
   
   if(once) {
      for(int i=idx; i<idx+10; i++) {
         PrintFormat("%d: %f", i, ExtMABuffer[i]);
      }
      once=false;
   }
   
   for(int i=idx; i<idx+CountPeriods; i++) {
      if(ExtMABuffer[i+1] >= Close[i+1] &&
          ExtMABuffer[i] < Close[i]) {
         crossCount++;
      } else if(ExtMABuffer[i+1] <= Close[i+1] &&
          ExtMABuffer[i] > Close[i]) {
         crossCount++;   
      }
   }
   
   return crossCount;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int i, pos;

   ArraySetAsSeries(ExtCrossBuffer, true);
   ArraySetAsSeries(ExtMABuffer, true);
   
   pos=rates_total - CountPeriods - prev_calculated - 1;
   for(i=pos+CountPeriods; i>=0; i--) {
      ExtMABuffer[i] = iMA(NULL, 0, MAperiod, 0, MODE_SMA, PRICE_CLOSE, i);
   }
   for(i=pos; i>=0; i--) {
      ExtCrossBuffer[i] = getCrossValue(i);
   }

   return(rates_total);
}
