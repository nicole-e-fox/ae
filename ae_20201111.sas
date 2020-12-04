/*
Your colleagues would like a daily e-mail that contains the 
stock prices of interest in the body of the email, and also 
a PDF attachment that they can use for printing or archiving.  

Write a SAS program that delivers this report and attachment 
in an e-mail message.

You can use the SASHELP.STOCKS data as a data source, 
or come up with your own.
*/

%macro getstock(stock=IBM,
                port=587,
                from=dancefloormechanix@gmail.com,
                to=fx@sxs.io,
                subject=Price as of,
                path=/folders/myfolders/tmp,
                pwfile=/folders/myfolders/tmp/pw.txt); 
data _null_;
      time = datetime();
      epoch = datetime() - ('01jan1970:0:0:0'dt-'01jan1960:0:0:0'dt);
      call symput ('startPeriod',compress(round(intnx('dtweekday', epoch, -6, 'same'))));
      call symput('endPeriod',compress(round(epoch)));
      call symput('today',put(today(),worddate.));
      call symput('yesterday',put(today()-1,worddate.));
put time= epoch= ; 
run;
%put &startPeriod &endPeriod &today &yesterday; 


/* use WORK location to store our temp files */
filename out "%sysfunc(getoption(WORK))/output.txt"; 
filename hdrout "%sysfunc(getoption(WORK))/response1.txt"; 
 
/* This PROC step caches the cookie for the website finance.yahoo.com */
/* and captures the web page for parsing later                        */
proc http 
  out=out
  headerout=hdrout
  url="https://finance.yahoo.com/quote/&stock/history?p=&stock" 
  method="get";
run;
 
/* Read the response and capture the cookie value from     */
/* the CrumbStore field.                                   */
/* The file has very long lines, longer than SAS can       */
/* store in a single variable.  So we read in <32k chunks. */
data crumb (keep=crumb);
  infile out  recfm=n lrecl=32767;
  /* the @@ directive says DON'T advance pointer to next line */
  input txt: $32767. @@;
  pos = find(txt,"CrumbStore");
  if (pos>0) then
    do;
      crumb = dequote(scan(substr(txt,pos),3,':{}'));
      /* cookie value can have unicode characters, so must URLENCODE */
      call symputx('getCrumb',urlencode(trim(crumb)));
      output;
    end;
run;
 
%put &=getCrumb.;
 
filename data "%sysfunc(getoption(WORK))/data.csv" ; 
filename hdrout2 "%sysfunc(getoption(WORK))/response2.txt" ; 

options mprint symbolgen; 

 
proc http 
    out=data
    headerout=hdrout2
    url="https://query1.finance.yahoo.com/v7/finance/download/%nrbquote(&stock)?period1=%str(&startPeriod.)%str(&)period2=%str(&endPeriod.)%str(&)interval=1d%str(&)events=history%str(&)crumb=&getCrumb."
    method="get";                               
run;

proc import
 file=data
 out=history
 dbms=csv
 replace;
run;

data history; 
     length stock $8; 
     set history; 
     Stock="&stock"; 
run; 

*%let workdir=%trim(%sysfunc(pathname(work)));
ods _ALL_ close; 
ods listing gpath="&path.";
ods graphics / reset=index outputfmt=PNG imagename="&stock.";  
title1 "%upcase(&stock) Price over the Last Seven Trading Days";
 
proc sgplot data=history;
  yaxis label="&stock Price"; 
  xaxis label="Time Period" minor; 
  highlow x=date high=high low=low / open=open close=close;  
run;

title1 "&stock Price as of &yesterday";
ods pdf file="&path./&stock..pdf"; 
proc print data=history(where=(date=(today()-1))) noobs label; 
run;
ods pdf close; 


/* send email to desginated user */
*filename pwfile "/folders/myfolders/tmp/pw.txt"; 
filename pwfile "&pwfile."; 
  	
data _null_;
   infile pwfile obs=1 length=l; 
   input @;
   input @1 line $varying1024. l; 
   call symput('pw',substr(line,1,l)); 
run;

%put &dbpass;  	

options emailhost=
 (
   "smtp.gmail.com" 
   /* alternate: port=487 SSL */
   port=&port STARTTLS 
   auth=plain 
   id="&from."
   pw=&pw
 )
;

proc options group=email;
run;
 
filename myemail EMAIL
  to="&to." 
  subject="%upcase(&stock) &subject. &yesterday."
  attach=("&path./&stock..pdf"
          "&path./&stock..png" inlined='sgplot');
 
data _null_;
     file myemail;
     set history(where=(date=(today()-1))); 
     put date= open= high= low= close= adj_close= volume= ; 
run;

 
filename myemail clear;
%mend getstock; 

%getstock(stock=armk);
%getstock(stock=ebay); 
%getstock(stock=ms); 

 