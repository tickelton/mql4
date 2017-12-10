//+------------------------------------------------------------------+
//|                                                    ttnCommon.mqh |
//|                                              tickelton@gmail.com |
//|                                     https://github.com/tickelton |
//+------------------------------------------------------------------+
#property copyright "tickelton@gmail.com"
#property link      "https://github.com/tickelton"
#property strict

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

#define ttnMagicNumberTurtleSystem1 5132
#define ttnMagicNumberTurtleSystem2 5133
#define ttnMagicNumberTrueSymphonie 5134
#define ttnMagicNumberHFOne 5135
#define ttnMagicNumber201703breakoutreversal 5136
#define ttnMagicNumber201704plateaudrawer 5137
#define ttnMagicNumber201705plateauReversal 5138
#define ttnMagicNumber201705CCIbreakoutReversal 5139
#define ttnMagicNumber201712MarketWeatherDualMA 5140
#define ttnMagicNumber201712MarketWeatherTripleMA 5141
#define ttnMagicNumber201712MarketWeatherRSI 5142
#define ttnMagicNumber201712MarketWeatherWpR 5143
#define ttnMagicNumber201712MarketWeatherStoch 5144

#define OP_NONE   9999

enum eLogLevel {
   LevelCritical = 0,
   LevelError = 1,
   LevelWarning = 2,
   LevelInfo = 3,
   LevelDebug = 4,
   LevelTrace = 5,
};

enum eTradeDirection {
   DIR_NONE,
   DIR_BUY,
   DIR_SELL,
};

enum eCorrelationType {
   CORRELATION_MILD,
   CORRELATION_STRONG,
};

int ttnDefaultSlippage = 3;
int ttnClrBuyOpen = clrBlue;
int ttnClrBuyClose = clrRed;
int ttnClrSellOpen = clrRed;
int ttnClrSellClose = clrBlue;
int ttnClrDelete = clrYellow;

#define N_CURRENCY_PAIRS 14
#define N_CORRELATION_PAIRS 13
struct sCorrelationTable {
   string name;
   string moderateCorrelation[N_CORRELATION_PAIRS];
   string strongCorrelation[N_CORRELATION_PAIRS];
};

sCorrelationTable CorrelationTable[N_CURRENCY_PAIRS] = {
   {
      "AUDJPY", 
      {"NZDUSD", "", "", "", "", "", "", "", "", "", "", "", ""},
      {"EURGBP", "EURJPY", "GBPCHF", "GBPJPY", "GBPUSD", "USDJPY", "", "", "", "", "", "", ""}
   },
   {
      "AUDUSD",
      {"EURGBP", "EURJPY", "GBPCHF", "GBPJPY", "GBPUSD", "USDAD", "USDJPY", "", "", "", "", "", ""},
      {"EURAUD", "NZDUSD", "", "", "", "", "", "", "", "", "", "", ""}
   },
   {
      "EURAUD",
      {"EURJPY", "GBPJPY", "GBPUSD", "NZDUSD", "", "", "", "", "", "", "", "", ""},
      {"AUDUSD", "", "", "", "", "", "", "", "", "", "", "", ""}
   },
   {
      "EURCHF",
      {"", "", "", "", "", "", "", "", "", "", "", "", ""},
      {"", "", "", "", "", "", "", "", "", "", "", "", ""}},
   {
      "EURGBP",
      {"AUDUSD", "", "", "", "", "", "", "", "", "", "", "", ""},
      {"AUDJPY", "EURJPY", "GBPCHF", "GBPJPY", "GBPUSD", "NZDUSD", "USDJPY", "", "", "", "", "", ""}
   },
   {
      "EURJPY",
      {"AUDUSD", "EURAUD", "", "", "", "", "", "", "", "", "", "", ""},
      {"AUDJPY", "EURGBP", "GBPCHF", "GBPJPY", "GBPUSD", "NZDUSD", "USDJPY", "", "", "", "", "", ""}
   },
   {
      "EURUSD",
      {"USDCAD", "", "", "", "", "", "", "", "", "", "", "", ""},
      {"USDCHF", "", "", "", "", "", "", "", "", "", "", "", ""}
   },
   {
      "GBPCHF",
      {"AUDUSD", "", "", "", "", "", "", "", "", "", "", "", ""},
      {"AUDJPY", "EURGBP", "EURJPY", "GBPJPY", "GBPUSD", "NZDUSD", "USDJPY", "", "", "", "", "", ""}
   },
   {
      "GBPJPY",
      {"AUDUSD", "EURAUD", "", "", "", "", "", "", "", "", "", "", ""},
      {"AUDJPY", "EURGBP", "EURJPY", "GBPCHF", "GBPUSD", "NZDUSD", "USDJPY", "", "", "", "", "", ""}
   },
   {
      "GBPUSD",
      {"AUDUSD", "EURAUD", "NZDUSD", "", "", "", "", "", "", "", "", "", ""},
      {"AUDJPY", "EURGBP", "EURJPY", "GBPCHF", "GBPJPY", "USDJPY", "", "", "", "", "", "", ""}
   },
   {
      "NZDUSD",
      {"AUDJPY", "EURAUD", "GBPUSD", "USDCAD", "", "", "", "", "", "", "", "", ""},
      {"AUDUSD", "EURGBP", "EURJPY", "GBPCHF", "GBPJPY", "USDJPY", "", "", "", "", "", "", ""}
   },
   {
      "USDCAD",
      {"AUDUSD", "EURUSD", "NZDUSD", "USDCHF", "", "", "", "", "", "", "", "", ""},
      {"", "", "", "", "", "", "", "", "", "", "", "", ""}
   },
   {
      "USDCHF",
      {"USDCAD", "", "", "", "", "", "", "", "", "", "", "", ""},
      {"EURUSD", "", "", "", "", "", "", "", "", "", "", "", ""}
   },
   {
      "USDJPY",
      {"AUDUSD", "", "", "", "", "", "", "", "", "", "", "", ""},
      {"AUDJPY", "EURGBP", "EURJPY", "GBPCHF", "GBPJPY", "GBPUSD", "NZDUSD", "", "", "", "", "", ""}
   },
};

struct s_linereg {
   double m;
   double b;
   double r;
};
