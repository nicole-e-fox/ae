/*
Repeating cycles - look for occurrences of shows that have been streamed
multiple times -- and the span of time between these events. Identify
"favorite" or "repeating touchstone" titles that the household seems to come
back to. Are there any? Create a chart or report to show any pattern.
*/


proc sort data=viewing2 (where=(contentType='Series')) out=sorted;
	by profile seriestitle obs date;
run;

proc summary data=sorted nway;
	by profile seriestitle;
	class date;
	output out=sumz(drop=_TYPE_ rename=(_FREQ_=Count));
run;

proc sql;
	create table sumz2 as select cats(profile, seriestitle) as key, * from sumz 
		order by key, date;
quit;

data YearDays;
	format Date prevDate Date9. daysLapsed 8.;
	set sumz2;
	by key date;

	prevDate=lag(date);
	daysLapsed=intck('day', prevdate, date);
	monthsLapsed=intck('month', prevdate, date);
	yearsLapsed=intck('year', prevdate, date);

	if first.key then
		prevdate=.;

	if first.key then
		daysLapsed=.;
		
	if first.key then
		monthsLapsed=.;
		
	if first.key then
		yearsLapsed=.;	
run;


%let TopN = 10;
%let VarName = seriesTitle;
proc freq data=yeardays  ORDER=FREQ noprint;  
     tables &VarName / out=TopOut;
run;

data Other;      * keep the values for the Top categories. Use "Others" for the smaller categories ;
	 set TopOut; 
	 label topCat = "Top Categories or 'Other'";
	 topCat = &VarName;       * name of original categorical var ;
	 if _n_ > &TopN then
	     topCat = "Other";    * merge smaller categories ;
	 if missing(&varname) then
	     topCat = "Other";    * clean up ; 
run;

proc sql noprint; 
     select min(date) format=worddate. into: startDate
     from viewing; 
     select max(date) format=worddate. into: endDate
     from viewing; 
quit; 
 
title "Netflix Top 10 TV Series Viewed (All Available Users)" ;
title2 "&startdate. - &endDate."; 

proc freq data=Other ORDER=data;   * order by data and use WEIGHT statement for counts ;
  tables TopCat / plots=FreqPlot(scale=percent);
  weight Count;                    
run;



%macro top10(dset=yeardays, profile=L, topN=10, VarName=seriesTitle);
	proc freq data=&dset. (where=(profile in("&profile."))) ORDER=FREQ noprint;
		* no print. Create output data set of all counts ;
		tables &VarName / out=TopOut;
	run;

	data Other;
		* keep the values for the Top categories. Use "Others" for the smaller categories ;
		set TopOut;
		label topCat="Top Titles or 'Other'";
		topCat=&VarName;
		* name of original categorical var ;

		if _n_ > &TopN then
			topCat="Other";
		* merge smaller categories ;
	run;

	title "&profile.'s Netflix Top 10 Series";

	proc freq data=Other ORDER=data;
		* order by data and use WEIGHT statement for counts ;
		tables TopCat / plots=FreqPlot(scale=percent) out=top10_&profile;
		weight Count;
	run;

%mend;

%top10;
%top10(profile=JEZ);
%top10(profile=X);
title 'Content Appearing in All Profiles';

proc sql;
	select a.topcat from top10_l a, top10_jez b, top10_x c where 
		a.topcat=b.topcat=c.topcat;
quit;

%macro summary(var=);
proc means data=yeardays nway noprint;
	where seriestitle=&var.;
	by profile;
	var dayslapsed monthslapsed count date; 
	output out=means(drop=_TYPE_ rename=(_FREQ_=NumberOfViewingDays))
	                 sum(count)=EpisodesViewed 
	                 min(date)=EarliestDate 
	                 max(date)=LatestDate
                     max(dayslapsed)=MaxDaysLapsed
                     max(monthslapsed)=MaxMonthsLapsed
	                 max(yearslapsed)=MaxYearsLapsed
	                 mean(dayslapsed)=AvgDaysLapsed
	                 mean(monthslapsed)=AvgMonthsLapsed
	                 /autolabel; 
run;

title &var. ; 
proc print data=means noobs ;
run;
title; 
%mend; 
%summary(var=%quote("Grey%'s Anatomy"));
%summary(var=%quote("Cheers"));
%summary(var=%quote("Friends"));
%summary(var=%quote("Gilmore Girls"));
%summary(var=%quote("How I Met Your Mother"));
%summary(var=%quote("Family Ties"));
%summary(var=%quote("Parks and Recreation"));
%summary(var=%quote("The X-Files"));
%summary(var=%quote("New Girl"));
%summary(var=%quote("House, M.D."));
footnote '(Series Still in Production)'; 
%summary(var=%quote("Trailer Park Boys"));
footnote;
