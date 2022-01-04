options spool mprint; 

FILENAME R1 '/home/u37551518/ae_data/NetflixViewingHistory_Z.csv';  
FILENAME R2 '/home/u37551518/ae_data/NetflixViewingHistory_J.csv';  
FILENAME R3 '/home/u37551518/ae_data/NetflixViewingHistory_X.csv';      
FILENAME R4 '/home/u37551518/ae_data/NetflixViewingHistory_L.csv'; 
 
proc format; 
     value wkend  0='Weekday'
                  1='Weekend'; 
run;  

%macro rdData(profile=,infile=); 
data &profile. (keep= obs profile2 year date weekend contenttype 
                title seriestitle season volumenum chapternum episodetitle episodenum partnum 
                rename=(profile2=profile));
     retain obs profile year date weekend contentType title series season; 
     length title $ 100 date 8 
        profile $ 40 season $8 part $8 volume $8; 
     format date date9.;
     infile &infile. dlm=',' dsd filename=in firstobs=2 truncover ; 
     input title date:??anydtdte.; 
     if date^=. and title ^="";
     
     *save row information for sorting; 
     obs=_N_; 
     
     *create year and weekend variables for analysis; 
     year=year(date);
     dayofweek=put(date,weekday.);
     if dayofweek in (2,3,4,5,6) then weekendFlag=0; 
     else weekendFlag=1; 
     weekend=put(weekendFlag,wkend.);      
     
     *create profile nickname; 
     profile=scan(in,-1,'\/');      
     profile2=substr(scan(profile,2,'_'),1,1); 
     
     *examine contents of string for parsing;      
     coloncheck=countc(title,':');     
     trailerFlag=0; 
     if indexw(propcase(title),'(Trailer)') then trailerFlag=1;
     seasonIndex=indexw(propcase(title),'Season '); 
     episodeIndex=indexw(propcase(title),'Episode '); 
     volumeIndex=indexw(propcase(title),'Volume '); 
     partIndex=indexw(propcase(title),'Part '); 
     chapterIndex=indexw(propcase(title),'Chapter '); 
     
     *classify content-type;     
     if trailerFlag > 0 and seasonIndex > 0 then contentType='Series Trailer'; 
     if trailerFlag > 0 and coloncheck = 0 then contentType='Movie Trailer';
     if trailerFlag = 0 and coloncheck <=1 then contentType='Movie';
     if trailerFlag = 0 and seasonIndex > 0 then contentType='Series'; 
     if trailerFlag = 0 and volumeIndex > 0 then contentType='Series';
     if trailerFlag = 0 and partIndex > 0 then contentType='Series';    
 
     *create serial-specific content;     
     if contentType in('Series','Series Trailer') then seriesTitle=scan(title,1,':');   
     else seriesTitle=''; 
     
     if seasonIndex > 0 then season=compress(substr(title,seasonIndex+7,15),,'p');  
     else season='';  season=scan(season,1,' ');
     
     if volumeIndex > 0 then volumenum=compress(substr(title,volumeIndex+7,8),,'p'); 
     else volumenum='';  volumenum=scan(volumenum,1,' ');
    
     if chapterIndex > 0 then chapternum=compress(substr(title,chapterIndex+7,15),',:');
     else chapternum='';      chapternum=scan(chapternum,1,' '); 

     if episodeIndex > 0 then episodenum=compress(substr(title,episodeIndex+7,15),'123456789I','k');    
     else episodenum=''; episodenum=scan(episodenum,1,' '); 
     
     if contentType in('Series','Series Trailer') and coloncheck=2 then 
        episodeTitle=scan(title,3,':');
         
     if contentType in('Series','Series Trailer') and coloncheck=3 then 
        episodeTitle=scan(title,3,':');
              
     if partIndex > 1 then partnum=compress(substr(title,partIndex+5,8),,'p');
     else partnum='';  partnum=scan(partnum,1,' ');    
run;
%mend; 
%rdData(profile=Z,infile=R1);
%rdData(profile=J,infile=R2);
%rdData(profile=X,infile=R3);
%rdData(profile=L,infile=R4);
data viewing; 
     set Z J X L; 
     *clean up profiles;
     if profile in('J','Z') then do; 
        profile='JEZ';
     end; 
     
run;



proc sql; 
     create table BingeTVEvents as
     select profile, year, date, weekend, seriestitle, count (seriestitle) as seriesN 
     from viewing
     where contentType='Series'
     group by  profile, year, date, weekend, seriestitle
     having seriesN > 1; 
quit;      

 
proc sql; 
     create table viewing2 as 
     select a.*, 
            case
                when b.seriesN > 1 then 1
                else 0
            end as BingeEvent
    from viewing a
     left join bingetvevents b
     on a.profile=b.profile and a.date=b.date and a.seriestitle=b.seriestitle
     order by  profile, year, date, weekend, seriestitle, obs; 
quit; 


%let TopN = 10;
%let VarName = seriesTitle;
proc freq data=viewing2 (where=(contentType='Series')) ORDER=FREQ noprint;  
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

%let VarName = title;
proc freq data=viewing2(where =(contentType='Movie')) ORDER=FREQ noprint;  
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
 
title "Netflix Top 10 Movie Titles Viewed (All Available Users)" ;
title2 "By Profile"; 
proc freq data=Other ORDER=data;   * order by data and use WEIGHT statement for counts ;
  tables TopCat / plots=FreqPlot(scale=percent);
  weight Count;                    
run;
title; title2; 

*clean up; 
proc datasets library=work kill nolist nodetails; 
run;
