filename pi url "https://introcs.cs.princeton.edu/java/data/pi-10million.txt" lrecl = 10000000;
data pi;
  infile pi missover;
  length pi $ 32767;
  do until (pi = '');
    input pi $char32767. +(-7) @;
    output;
  end;
run; 

%let date='01DEC1998'd; 
data _null_;
  set pi;
  file print;
  date = &date;
  x = index(pi, put(date, mmddyy6.));
  datestr_returned_from_pi=substr(pi,x,6);
  if x then do;
    pos = sum(32760 * i, x);
    put date= date9. date= mmddyy8. pos= comma15. datestr_returned_from_pi=; 
    stop;
  end;
run;
