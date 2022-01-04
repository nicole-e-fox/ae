data _null_;  
     March=0;  
     April=0;  
     do year=1901 to 2000;  
 	    if month(holiday('EASTER',year)) = 3 then March+1; 
 	    else if month(holiday('EASTER',year)) = 4 then April+1; 
 	 end; 	  
 	 putlog '# of Sundays by Month: ' March= 'versus ' April=;  
run; 
