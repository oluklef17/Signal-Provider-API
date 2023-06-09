//+------------------------------------------------------------------+
//|                                        TelegramToMT4.mq4 |
//|                                           Copyright 2022,Oluyemi Sodipo |
//|                                             https://www.jarvistrade.io |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021,www.javistrade.io"
#property link      "https://www.jarvistrade.io"
#property version   "1.00"
#property strict

//================================================
//OBSERVER CLASS

string        cookie       = NULL,headers;
char          post[];
int           resu;


string        message;

char          results[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CTradeObserver
  {
   typedef void      (*TOnTradeHandler)();

   enum ENUM_ORDER_DATA
     {
      order_ticket,
      order_closetime,
      order_commission,
      order_expiration,
      order_lots,
      order_magicNumber,
      order_openPrice,
      order_openTime,
      order_stopLoss,
      order_takeProfit,
      order_type,

      order_closePrice,
      order_profit,
      order_swap,

      order_last,
      order_limit = order_type,

     };

   struct STradeObserverData
     {
      int            count;
      double         trades[][order_last];
     };

private:

protected:
   TOnTradeHandler    mHandler;
   STradeObserverData mPreviousData;
   void              Fill(STradeObserverData &data);
   void              GetChanged(STradeObserverData &data, STradeObserverData &data2);

public:
   string            mMessage;
   string            mToken;
   string            mChatID;
   int               mNewTicket;
   string            mMessageID;
   string            mTicketMsgId[];
   double            OldTickets[];
   double            NewTickets[];
                     CTradeObserver(TOnTradeHandler handler);
                    ~CTradeObserver();

   bool              IsFound(double data, double &array[]);
   void              AddToArray(double &array[], double value);
   void              AddToArray(string &array[], string value);
   void              StartScan();
   string            SendMessage(string msg, string id);
   string            GetTicketID(int ticket);
   void              ReplaceTicketID(string id, int newTicket);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTradeObserver::CTradeObserver(TOnTradeHandler handler)
  {

   mHandler = handler;
   Fill(mPreviousData);

   for(int i=0; i<mPreviousData.count; i++)
     {
      AddToArray(OldTickets,mPreviousData.trades[i][0]);
     }

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTradeObserver::~CTradeObserver(void)
  {

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTradeObserver::Fill(STradeObserverData &data)
  {

   data.count = OrdersTotal();
   ArrayResize(data.trades, data.count);
   for(int i=0; i<data.count; i++)
     {
      data.trades[i][order_ticket] = 0;
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      data.trades[i][order_ticket] = OrderTicket();
      data.trades[i][order_closePrice] = OrderClosePrice();
      data.trades[i][order_closetime] = (double)OrderCloseTime();
      data.trades[i][order_commission] = OrderCommission();
      data.trades[i][order_expiration] = (double)OrderExpiration();
      data.trades[i][order_lots] = OrderLots();
      data.trades[i][order_magicNumber] = OrderMagicNumber();
      data.trades[i][order_openPrice] = OrderOpenPrice();
      data.trades[i][order_openTime] = (double)OrderOpenTime();
      data.trades[i][order_profit] = OrderProfit();
      data.trades[i][order_stopLoss] = OrderStopLoss();
      data.trades[i][order_swap] = OrderSwap();
      data.trades[i][order_takeProfit] = OrderTakeProfit();
      data.trades[i][order_type] = OrderType();
     }

   if(ArraySize(data.trades) > 0)
      ArraySort(data.trades);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTradeObserver::StartScan()
  {

   STradeObserverData currentData;
   Fill(currentData);

   ArrayFree(NewTickets);
   for(int i=0; i<currentData.count; i++)
     {
      AddToArray(NewTickets,currentData.trades[i][0]);
     }

   bool changed = false;

   if(currentData.count!=mPreviousData.count)
     {

      if(currentData.count > mPreviousData.count)
        {
         int ticket = (int)currentData.trades[currentData.count-1][0];
         int type = -1;
         string symbol = "";
         double sl = 0;
         double tp = 0;
         double open = 0;
         string ordertype = "";



         if(OrderSelect(ticket,SELECT_BY_TICKET))
           {
            type   = OrderType();
            symbol = OrderSymbol();
            sl     = OrderStopLoss();
            tp     = OrderTakeProfit();
            open   = OrderOpenPrice();
            ordertype = type==0 ? "BUY" : type==1 ? "SELL" : type==2 ? "BUYLIMIT" : type==3 ? "SELLLIMIT" : type==4 ? "BUYSTOP" : "SELLSTOP";
            mMessage = ordertype+" "+symbol+" @ "+(string)open+"                                                                                                                          SL: "+(string)sl
                       +"                                                                                                                                              TP: "+(string)tp;
           }

         string id = SendMessage(mMessage);

         AddToArray(mTicketMsgId,(string)ticket+","+id);

       //  Alert(mTicketMsgId[ArraySize(mTicketMsgId)-1]);
        }

      else
         if(currentData.count < mPreviousData.count)
           {
            for(int i=0; i<mPreviousData.count; i++)
              {
               if(!IsFound(mPreviousData.trades[i][0],NewTickets))
                 {
                  int ticket = (int)mPreviousData.trades[i][0];
                  int type = -1;
                  string symbol = "";
                  double sl = 0;
                  double tp = 0;
                  string ordertype = "";
                  double profit = 0;

                  if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_HISTORY))
                    {
                     type   = OrderType();
                     symbol = OrderSymbol();
                     sl     = OrderStopLoss();
                     tp     = OrderTakeProfit();
                     profit = OrderProfit();
                     ordertype = type==0 ? "BUY" : type==1 ? "SELL" : type==2 ? "BUYLIMIT" : type==3 ? "SELLLIMIT" : type==4 ? "BUYSTOP" : "SELLSTOP";
                     StringToLower(ordertype);

                     if(type <= 1)
                       {
                        if(profit < 0)
                          {
                           mMessage = symbol+" close now in loss.";
                          }

                        else
                           if(profit >= 0)
                             {
                              mMessage = symbol+" close now in profit.";
                             }
                       }
                      
                     else
                      mMessage = "Delete "+symbol+" "+ordertype+" order.";

                    }

                  SendMessage(mMessage,GetTicketID(ticket));
                  //Alert("ID of original message is ",GetTicketID(ticket));
                 }
              }

           }

      changed = true;
     }
   else
     {
      for(int i=0; !changed && i<currentData.count; i++)
        {
         for(int j=0; !changed && j<order_limit; j++)
           {
            if(currentData.trades[i][j] != mPreviousData.trades[i][j])
              {
               string symbol = "";
               int ticket = 0;

               if(OrderSelect((int)mPreviousData.trades[i][0],SELECT_BY_TICKET))
                 {
                  ticket = OrderTicket();
                  symbol = OrderSymbol();
                 }

               string sourceID = GetTicketID(ticket);

               string symTag = sourceID == "" ? " for "+symbol : "";

               if(j==8)
                 {
                  double minPips = SymbolInfoDouble(symbol,SYMBOL_ASK)-SymbolInfoDouble(symbol,SYMBOL_BID);
                  
                  mMessage = (currentData.trades[i][10]==OP_BUY ? currentData.trades[i][8] >= currentData.trades[i][6] && currentData.trades[i][8]-currentData.trades[i][6] <= minPips : currentData.trades[i][8] <= currentData.trades[i][6] && currentData.trades[i][6]-currentData.trades[i][8] <= minPips )? "Move SL to breakeven "+symTag : "Move SL to "+(string)currentData.trades[i][8]+symTag;

                  SendMessage(mMessage,sourceID);
                  //Alert("ID of original message is ",GetTicketID(ticket));
                 }

               if(j==9)
                 {
                  mMessage = "Move TP to "+(string)currentData.trades[i][9]+symTag;

                  SendMessage(mMessage,sourceID);
                  //  Alert("ID of original message is ",GetTicketID(ticket));
                 }

               if(j==0)
                 {
                  ReplaceTicketID(sourceID,(int)currentData.trades[i][0]);
                  mMessage = "Close half lot "+symTag;
                  // Alert("ID of original message is ",GetTicketID(ticket));
                  SendMessage(mMessage,sourceID);
                 }

               changed = true;
               break;
              }
           }
        }
     }

   mPreviousData = currentData;

   ArrayFree(OldTickets);
   for(int i=0; i<currentData.count; i++)
     {
      AddToArray(OldTickets,currentData.trades[i][0]);
     }

   if(changed)
     {
      mHandler();
     }

   return;
  }
//+------------------------------------------------------------------+
void CTradeObserver::GetChanged(STradeObserverData &data,STradeObserverData &data2)
  {


  }
//+------------------------------------------------------------------+
bool CTradeObserver::IsFound(double data,double &array[])
  {

   for(int i=0; i<ArraySize(array); i++)
     {
      if(data == array[i])
         return(true);
     }

   return(false);
  }
//+------------------------------------------------------------------+
void CTradeObserver::AddToArray(double &array[],double value)
  {

   ArrayResize(array, ArraySize(array)+1);
   array[ArraySize(array)-1] = value;

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTradeObserver::AddToArray(string &array[],string value)
  {

   ArrayResize(array, ArraySize(array)+1);
   array[ArraySize(array)-1] = value;

  }
//+------------------------------------------------------------------+
string CTradeObserver::SendMessage(string msg, string id="")
  {

   int timeout = 2000;

   string url = "https://api.telegram.org/bot"+mToken+"/sendMessage?chat_id="+mChatID+"&text="+msg;

   if(id=="")
      resu = WebRequest("GET",url,cookie,NULL,timeout,post,0,results,headers);

   else
     {
      url = "https://api.telegram.org/bot"+mToken+"/sendMessage?chat_id="+mChatID+"&text="+msg+"&reply_to_message_id="+id;
      resu = WebRequest("GET",url,cookie,NULL,timeout,post,0,results,headers);
     }

   string response = "";

   if(resu==200)
     {
      response = CharArrayToString(results);

      response = StringSubstr(response,22);
      response = StringSubstr(response,0,StringFind(response,","));

      StringReplace(response,"message_id\":","");
     }
   
   else
    Comment("Failed to send message. Error = ",GetLastError());

   return response;
  }
//+------------------------------------------------------------------+
string CTradeObserver::GetTicketID(int ticket)
  {

   string id = "";

   for(int i=0; i<ArraySize(mTicketMsgId); i++)
     {
      if(StringFind(mTicketMsgId[i],(string)ticket) >= 0)
        {

         string parts[];

         StringSplit(mTicketMsgId[i],StringGetCharacter(",",0),parts);

         if(ArraySize(parts) > 1)
           {
            id = parts[1];
            break;
           }
        }
     }


   return id;
  }
//+------------------------------------------------------------------+
void CTradeObserver::ReplaceTicketID(string id, int newTicket)
  {


   for(int i=0; i<ArraySize(mTicketMsgId); i++)
     {
      if(StringFind(mTicketMsgId[i],id) >= 0)
        {

         mTicketMsgId[i] = (string)newTicket+","+id;
         break;
        }
     }


  }
//+------------------------------------------------------------------+




//================================================

CTradeObserver *Observer;



input string InpToken  = "5797171502:AAHOIdON92PM_N_ocjKqzPZwzxuEDOK_7N8";//Bot API Token
input string InpChatID = "";//Chat ID

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Observer = new CTradeObserver(OnTrade);

   Observer.mToken  = InpToken;
   Observer.mChatID = InpChatID;

   int handle = FileOpen("TicketMsgID.txt",FILE_READ);

   if(handle==INVALID_HANDLE)
     {
      Print("Failed to read file. ",__FUNCTION__," (",GetLastError(),")");
     }

   while(!FileIsEnding(handle))
     {
      AddToArray(Observer.mTicketMsgId,FileReadString(handle));
     }

   FileClose(handle);
   
 /*  for(int i=0;i<ArraySize(Observer.mTicketMsgId);i++)
     {
       Print("TMI = ",Observer.mTicketMsgId[i]);
     }*/

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   int handle = FileOpen("TicketMsgID.txt",FILE_WRITE);

   if(handle==INVALID_HANDLE)
     {
      Print("Failed to write file. ",__FUNCTION__," (",GetLastError(),")");
     }

   for(int i=0; i<ArraySize(Observer.mTicketMsgId); i++)
     {
      FileWriteString(handle,Observer.mTicketMsgId[i]+"\n");
     }

   FileClose(handle);

   delete Observer;

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   Observer.StartScan();

  }
//+------------------------------------------------------------------+
void OnTrade()
  {
// SendMessage(Observer.mMessage);
//MessageBox(Observer.mMessage);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SendMessage(string msg)
  {

   int timeout = 2000;

   string url = "https://api.telegram.org/bot"+InpToken+"/sendMessage?chat_id="+InpChatID+"&text="+msg;

   resu = WebRequest("GET",url,cookie,NULL,timeout,post,0,results,headers);

  }
//+------------------------------------------------------------------+
void AddToArray(string &array[], string value)
  {

   ArrayResize(array, ArraySize(array)+1);
   array[ArraySize(array)-1] = value;

  }
//+------------------------------------------------------------------+
