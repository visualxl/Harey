#property description "RSI based EA. Different pairs have different optimizaition parameters. \n"
#property description "Optimized for: \n 1. GBP/USD (M5) \n 2. USD/CAD (M5) \n 3. AUD/USD (M5) \n"
#property description "Please ensure you have the corresponding SET files for each currency pair. Otherwise, it will not work! \n"
#property description "Last modified: 23/November/2020"
#property version "1.1"
#property copyright "Copyright 2020 | Syahmul Aziz."
#property link      "https://www.SyahmulAziz.com"

/* 
      HAREY INDICATORS:
      1. RSI
      
      HAREY ENTRY RULES:
      1. Buy when price go into the oversold level.
      2. Sell when price go into the overbought level.
   
      HAREY EXIT RULES:
      1. Fixed SL & TP depending on the pair.
      
      HAREY POSITION SIZING RULE:
      Sizing is either by:
      1. Free account margin
      2. Fixed lot size determined by the user.
   */

#define SIGNAL_NONE 0
#define SIGNAL_BUY   1
#define SIGNAL_SELL  2

/* ================ USER DEFINED INPUTS ================ */
extern int MagicNumber = 21112020; //Give unique numbers for each pair
enum MoneyManagement {
    No,
    Yes
};
input MoneyManagement AutoLotSize = No; //Use money management
input double Risk = 1; //Risk per trade in Percentage
extern double LotSize = 0.1; //Lot size
input int StartRestHour = 3; //Stop trading
input int EndRestHour = 8;//Start trading
//input double MaxSpread = 3; //Max spread I believe this is covered by slippage
input int MaxOpenTrades = 3;//Max open trades
extern double StopLoss = 30;
extern double TakeProfit = 30;
extern int RSI_Oversold = 40;
extern int RSI_Overbought = 60;

/* ================ EA VARIABLES ================ */
int Slippage = 3; //Max spread I believe

/* ================ ORDER VARIABLES ================ */
int P = 1;
int Order = SIGNAL_NONE;
int Total, Ticket, Ticket2;
double StopLossLevel, TakeProfitLevel, StopLevel;
bool isYenPair = false;

int OnInit(){
   if(Digits == 5 || Digits == 3 || Digits == 1)P = 10;else P = 1; // To account for 5 digit brokers
   if(Digits == 3 || Digits == 2) isYenPair = true; // Adjust for YenPair
   
   return(INIT_SUCCEEDED);
}

int start(){
   //Total = OrdersTotal();
   Total = GetTotalOrderByMagic(MagicNumber);
   Order = SIGNAL_NONE;
   
   //Don't execute the rest of the codes if there are 3 or more open trades.
   if(Total >= MaxOpenTrades)
      return 0;
   
   //Calculate RSI value
   double RSIValue = iRSI(_Symbol, _Period, 14, PRICE_CLOSE, 0);
   
   /******* Stop Level *******/
   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD)) / P;  // Defining minimum StopLevel
   if (StopLoss < StopLevel) StopLoss = StopLevel;
   if (TakeProfit < StopLevel) TakeProfit = StopLevel;
   
   /******* Money Management *******/
   if (AutoLotSize) {
      LotSize = Risk * 0.01 * AccountFreeMargin() / (MarketInfo(Symbol(),MODE_LOTSIZE) * StopLoss * P * Point); // Sizing Algo based on account size
      if(isYenPair == true) LotSize = LotSize * 100; // Adjust for Yen Pairs
      LotSize = NormalizeDouble(LotSize, 2); // Round to 2 decimal place
   }
   
   if (New_Bar()) {
      if(RSIValue < RSI_Oversold) Order = SIGNAL_BUY;
      if(RSIValue > RSI_Overbought) Order = SIGNAL_SELL;
      //Comment("RSI: " + (string) RSIValue + " Signal: " + Order);
      Comment("Symbol: " + _Symbol + "\nRSI: " + (string) RSIValue + "\nSignal: " + Order + "\nTotal order: " + Total);
   }
   
   //Check free margin
   if (AccountFreeMargin() < (1000 * LotSize)) {
     Comment("We have no money. Free Margin = ", AccountFreeMargin());
     return(0);
   }
   
   /******* Buy Order *******/
    if (Order == SIGNAL_BUY) {
      StopLossLevel = Ask - StopLoss * Point * P;
      TakeProfitLevel = Ask + TakeProfit * Point * P;
      Ticket = OrderSend(Symbol(), OP_BUY, LotSize, Ask, Slippage, StopLossLevel, TakeProfitLevel, "Buy(#" + (string) MagicNumber + ")", MagicNumber, 0, DodgerBlue);
         
      if(Ticket > 0) {
         if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES))
            Print("BUY order opened : ", OrderOpenPrice());
   		else Print("Error opening BUY order : ", GetLastError());
      }    
      return 0;
   } //end of buy
   
   /******* Sell Order *******/
   if (Order == SIGNAL_SELL) {
      StopLossLevel = Bid + StopLoss * Point * P;
      TakeProfitLevel = Bid - TakeProfit * Point * P;
      Ticket = OrderSend(Symbol(), OP_SELL, LotSize, Bid, Slippage, StopLossLevel, TakeProfitLevel, "Sell(#" + (string) MagicNumber + ")", MagicNumber, 0, DeepPink);
         
      if(Ticket > 0) {
         if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES))
		      Print("SELL order opened : ", OrderOpenPrice());       
   	   else Print("Error opening SELL order : ", GetLastError());
      }
      return(0);
   } //End of sell
   
   return 0;
}

//Only evaluate a trade on a new bar.
bool New_Bar() {
   static datetime New_Time=0; // New_Time = 0 when New_Bar() is first called
   if(New_Time!=Time[0]){      // If New_Time is not the same as the time of the current bar's open, this is a new bar
      New_Time=Time[0];        // Assign New_Time as time of current bar's open
      return(true);
   }
   return(false);
}

//Get the total order based on the magic number
int GetTotalOrderByMagic(int magic) {   
   int TotalOrderByMagic = 0;
   for(int cnt = 0; cnt < OrdersTotal(); cnt++){
       OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
       if(OrderMagicNumber() == magic) TotalOrderByMagic ++;
   }
   return(TotalOrderByMagic);
}