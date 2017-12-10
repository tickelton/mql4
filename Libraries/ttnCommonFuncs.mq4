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

#property library

#include <ttnCommon.mqh>

// fits a line through Close[n] to Close[m]
// using the least squares fit algorithm.
s_linereg linereg(int n, int m) export
{
   double count = n - m + 1.0;
   s_linereg s_line;
   
   s_line.m = 0;
   s_line.b = 0;
   s_line.r = 0;
   
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
      return s_line;
   }
   s_line.m = (count * sumxy - sumx * sumy) / denom;
   s_line.b = (sumy * sumx2 - sumx * sumxy) / denom;
   s_line.r = (sumxy - sumx * sumy / count) /
          sqrt((sumx2 - (sumx * sumx)/count) *
          (sumy2 - (sumy * sumy)/count));

   return s_line;
}

// Calculates the difference between two timestamps
// in units of Period() of the current Chart.
int getTimeDiff(datetime time1, datetime time2) export
{
   int timeDiff = (int)(time1 - time2);
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
   
   if(timeDiff < 0)
      return -timeDiff;
   
   return timeDiff;
}

void LogTerminal(eLogLevel level, eLogLevel gLevel, string s) export
{
   if(level <= gLevel)
      Print(s);
}

