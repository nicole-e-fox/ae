/*
If you have multiple years of streaming data, use the earlier data to create a
forecast of the most recent periods...and then plot that against the actual
streaming data you've collected.

IF NOT then

Create a rolling 7-day average of "numbers of titles streamed" and visualize in
a plot. AND Create a forecast of streaming activity (# of titles, and/or # of minutes/hours)
for the 3 months following the end of your streaming data. Include bands that indicate confidence limits.
*/
proc sort data=viewing out=sorted (keep=profile date weekend contenttype title);
	by profile descending date;
run;

data sorted;
	set sorted;

	if weekend='Weekday' then
		wkend=0;
	else
		wkend=1;
run;

proc summary data=sorted nway;
	by profile;
	class date;
	output out=sumz(drop=_TYPE_ rename=(_FREQ_=N));
run;

proc timedata data=sumz seasonality=52 out=tsdata;
	by profile;
	id date interval=week setmissing=0;
	var N / accumulate=total transform=none;
run;

proc sql;
	select profile, min(date) format=weekdatx17. as minDate, max(date) 
		format=weekdatx17. as Maxdate from tsdata group by profile;
quit;

proc ucm data=tsdata;
	id date interval=week;
	model N;
	level variance=0 noest;
	season length=52 type=trig;
	cycle plot=smooth;
	estimate; *plot=(normal acf) outest=estimates;
	forecast lead=12 alpha=0.05 plot=(decomp) outfor=forecast;
	by profile;
run;

proc sql;
	select profile, min(date) format=weekdatx17. as minDate, max(date) 
		format=weekdatx17. as Maxdate from forecast group by profile;
quit;

data forecast_sub(rename=(N=Actual));
	set forecast (where=(date >= today()-365));
run;

proc sort data=WORK.forecast_sub out=forecast_sorted;
	by profile date;
run;

proc sgplot data=forecast_sorted;
	by profile;
	title height=12pt "Forecast for Number of Titles Watched by Profile";
	series x=date y=Actual / markers markerattrs=(symbol=circle color=blue) 
		lineattrs=(color=blue);
	series x=date y=forecast / markers markerattrs=(symbol=circle color=red) 
		lineattrs=(color=red);
	xaxis grid interval=week label="Week";
	yaxis grid label="# of Titles Watched";
run;
