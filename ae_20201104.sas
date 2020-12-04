/*
The Collatz Conjecture Begin with any integer.  If it is an even number, you
divide it by two.  If it is odd, you multiply it by 3 and you add 1. If this 
new number is even, you divide it by 2 and if it is not, you multiply it by 3 
and you add 1. Repeat this process until the current number is equal to 1. The
resulting series of integers is called a Syracuse series.  This little game
stops when you get to 1 and, it seems, we always get to 1. Write a SAS program
which, starting from an integer drawn at random, will print its Syracuse
sequence into the log or results window.

For an additional challenge, generate a line plot of the sequence for each of
the following integers: 11, 37, 105. X-axis should be the position of the
number in the sequence, and Y-axis should be the current value for that
number.
*/	
%macro CollatzConjectureRandInt(stopValue=1);
 	data SyracuseSeries;
		int=int(ranuni(0) * 10**2);
            putlog "Random Seed " int=; 
		do while (int ne &stopValue);
			i+1;

			if mod(int, 2) eq 0 then
				int=int / 2;
			else
				int=int * 3 + 1;
			output;
			putlog int=&stopValue;
		end;
	run;
    title 'Syracuse Series using Randomly Generated Seed';
	proc sgplot data=SyracuseSeries;
		series x=i y=int;
	run;
	
	proc datasets library=work kill nodetails nolist; 
	run; 
%mend;
%CollatzConjectureRandInt;
%CollatzConjectureRandInt;
%CollatzConjectureRandInt;

options mprint symbolgen; 
%macro CollatzConjectureUser(stopValue=1,int=);
 	data SyracuseSeries;
		int=input("&int.",8.);
		do while (int ne &stopValue);
			i+1;

			if mod(int, 2) eq 0 then
				int=int / 2;
			else
				int=int * 3 + 1;
			output;
			putlog int=&stopValue;
		end;
	run;
    title "Syracuse Series using User-Defined Value &int."; 
	proc sgplot data=SyracuseSeries;
		series x=i y=int;
	run;
	title; 

	proc datasets library=work kill nodetails nolist; 
	run; 
%mend;
%CollatzConjectureUser(int=11);
%CollatzConjectureUser(int=37);
%CollatzConjectureUser(int=105);