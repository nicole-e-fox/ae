/*
You've just been asked by your CFO to provide a list of your 
biggest customers and how much they spend within a 2 month period.  
Please create the code to show the 60 days rolling sum of the 
transaction amount by customer ID using the table below:
*/

options nocenter; 

data transactions ;
input id  trn_date :date9. amount;
format trn_date date9.;
cards;
1 01jan2010 50
1 11jan2010 15
1 21jan2010 13
1 01feb2010 16
1 01mar2010 75
1 01apr2010 15
1 01may2010 10
2 01jan2010 50
2 01jan2010 55
2 11jan2010 15
2 21jan2010 13
2 01mar2010 20
2 11mar2010 60
2 04apr2010 6
2 11apr2010 20
2 01may2010 23
2 04may2010 45
2 01jun2010 15
2 11jun2010 60
3 01feb2010 60
3 11feb2010 24
3 13feb2010 15
;
run;

proc summary data=transactions nway; 
     class id trn_date; 
     var amount; 
     output out=sumz1(drop=_TYPE_ _FREQ_) sum=; 
run;

proc sql;
     create table tx as
	 select a.id, a.trn_date, a.amount as tx_amount, sum(b.amount) as roll60d_amount
	 from sumz1 as a
	 left join transactions as b on a.id = b.id 
	      and a.trn_date - 60 <= b.trn_date <= a.trn_date
	 group by a.id, a.trn_date, a.amount
	 order by a.id, a.trn_date;
quit;   

proc summary data=tx nway; 
     class id; 
     var tx_amount roll60d_amount; 
     output out=sumz(drop=_TYPE_ _FREQ_) sum(tx_amount)= mean(roll60d_amount)=; 
run;

proc sort data=sumz; 
     by descending tx_amount; 
run;

proc datasets library=work nodetails nolist; 
     modify sumz; 
            format roll60d_amount tx_amount dollar8.2; 
            label roll60d_amount = 'Average Spending by Customer in a 60-Day Perid'
                  tx_amount      = 'Sum of Customer Spend'
                  id             = 'Customer ID'; 
     modify tx; 
            label id             = 'Customer ID'
                  trn_date       = 'Transaction Date'
                  tx_amount      = 'Transaction Amount'
                  roll60d_amount = 'Rolling 60 Day Customer Spend'; 
quit; 
 
title 'Customer Summary'; 
title2 '(Sorted by Lifetime Spend)'; 
proc print data=sumz noobs label; 
run;

title 'Transaction History'; 
title2; 
proc print data=tx noobs label;
by id;  
run;  
     
title;      
proc datasets library=work nodetails nolist kill; 
quit; 

