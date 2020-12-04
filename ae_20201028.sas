/*  There is a compiled macro in your library that takes 3 arguments (a b c), and 
	creates 3 values (add1 add2 add3). When the arguments are all non-missing the 
	values are all the same and equals to the total of the arguments, but not if 
	one or more arguments are missing. Can you recreate the macro code? */ 
	
options mprint symbolgen;

%macro addition3(a=, b=, c=);
	add1=&a + &b + &c;
	add2=sum(&a, &b, &c);
	add3=mean(&a, &b, &c)*count(%nrstr("mean(&a, &b, &c)"), %nrstr("&"));
%mend;

DATA _NULL_;
	%addition3(a=1, b=5, c=9);
	PUT add1=add2=add3=;
	/*add1=15 add2=15 add3=15*/

     %addition3(a=4, b=2, c=.);
	PUT add1=add2=add3=;
	/*add1=. add2=6 add3=9*/

     %addition3(a=., b=7, c=.);
	PUT add1=add2=add3=;
	/*add1=. add2=7 add3=21*/
run;

data _null_;
	%addition3(a=., b=6, c=2);
	PUT add1=add2=add3=;
	/*add1=. add2=8 add3=12*/
RUN;