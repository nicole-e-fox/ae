FILENAME R1 '/home/u37551518/ae_data/NetflixViewingHistory_Z.csv';  
FILENAME R2 '/home/u37551518/ae_data/NetflixViewingHistory_J.csv';  
FILENAME R3 '/home/u37551518/ae_data/NetflixViewingHistory_X.csv';      
FILENAME R4 '/home/u37551518/ae_data/NetflixViewingHistory_L.csv'; 
 
proc format; 
     value wkend  0='Weekday'
                  1='Weekend'; 
run;  

%macro rdData(profile=,infile=); 
data &profile. (keep= obs profile year_watched date weekend contenttype 
                title seriestitle season volumenum chapternum episodetitle episodenum partnum 
                );
     retain obs profile year_watched date weekend contentType title series season; 
     length title $ 100 date 8 
        profile $ 40 season $8 part $8 volume $8 in $250; 
     format date date9.;
     infile &infile. dlm=',' dsd filename=in firstobs=2 truncover ; 
     input title date:??anydtdte.; 
     if date^=. and title ^="";
     
     *save row information for sorting; 
     obs=_N_; 
     
     *create year and weekend variables for analysis; 
     year_watched=year(date);
     dayofweek=put(date,weekday.);
     if dayofweek in (2,3,4,5,6) then weekendFlag=0; 
     else weekendFlag=1; 
     weekend=put(weekendFlag,wkend.);      
     
     *create profile nickname; 
     profile=scan(in,-1,'\/');      
     profile2=substr(scan(profile,2,'_'),1,1);
     drop profile; rename profile2=profile; 
     
     *examine contents of string for parsing;      
     coloncheck=countc(title,':');     
     trailerFlag=0; 
     if indexw(propcase(title),'(Trailer)') then trailerFlag=1;
     seasonIndex=indexw(propcase(title),'Season '); 
     episodeIndex=indexw(propcase(title),'Episode '); 
     volumeIndex=indexw(propcase(title),'Volume '); 
     partIndex=indexw(propcase(title),'Part '); 
     chapterIndex=indexw(propcase(title),'Chapter '); 
     chaptersIndex=indexw(propcase(title),'Chapter '); 
     
     *classify content-type;     
     if trailerFlag > 0 and seasonIndex > 0 then contentType='Series Trailer'; 
     if trailerFlag > 0 and coloncheck = 0 then contentType='Movie Trailer';
     if trailerFlag = 0 and coloncheck <=1 then contentType='Movie';
     
     if trailerFlag = 0 and coloncheck >=2 then contentType='Series';
     if trailerFlag = 0 and seasonIndex > 0 then contentType='Series'; 
     if trailerFlag = 0 and chapterIndex > 0 then contentType='Series';
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

     if chaptersIndex > 0 then chaptersnum=compress(substr(title,chapterIndex+8,15),',:');
     else chapternum='';      chapternum=scan(chaptersnum,1,' ');

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
     select profile, year_watched, 
     
     
     
     
     date, weekend, seriestitle, count (seriestitle) as seriesN 
     from viewing
     where contentType='Series'
     group by  profile, year_watched, date, weekend, seriestitle
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
     order by  profile, year_watched, date, weekend, seriestitle, obs; 
quit; 

options symbolgen;
libname ae '/home/u37551518/ae_data';
filename resp '/home/u37551518/ae_data/search.json';

%macro getOMDB(path=/home/u37551518/ae_data, type=, apikey=, name=,dset=viewing2);
	*create search-friendly lookup title;

	proc sort data=&dset(where=(lowcase(contentType)="&type") 
			keep=contentType &name year) out=sorted nodupkey;
		by &name;
	run;

	data &type;
		set sorted;
		lookup_title=lowcase(&name);
		lookup_title=translate(trim(lookup_title), '+', ' '); *adjust blank spaces beteween words; 
		lookup_title=tranwrd(lookup_title, "'", "%'");   *adjust single quotes; 
		lookup_title=tranwrd(lookup_title, ",", "%2C");  *adjust commas in search string; 
		lookup_title=tranwrd(lookup_title, ":", "%3A'"); *adjust colons in search string; 
		qtitle=tranwrd(title, "'", "%'");
		rename year=year_watched;
	run;

	proc sql noprint;
		select count (distinct lookup_title) into: N from &type.;
		create table lookup as select distinct lookup_title, &name, year_watched , qtitle
			from 
			&type;
	quit;

	%put &N.;

	data _null_;
		set lookup;
		call symput('lookuptitle'||left(_n_), trim(lookup_title) );
		call symput('qtitle'||left(_n_), trim(qtitle) );
	run;

	*retrieve OMDB API data using a search;
	%DO I=1 %TO &N.;
		%PUT %quote(&&qtitle&I);
		%let urlstring="http://www.omdbapi.com/?%nrstr(&t)=%nrbquote(&&lookuptitle&i)%nrstr(&type)=%str(&type)%nrstr(&apikey)=%str(&)";
		%put &urlstring;
		libname jout JSON fileref="resp"; *map="&path/search_map" automap=create;

		proc http url=&urlstring. out=resp method="GET";
		run;

		libname jout JSON fileref="resp";

		%if %sysfunc(exist(jout.root)) %then
			%do;

				proc sql;
					create table title as select distinct b.title length=200 as title, 
						"&&lookuptitle&i" length=200 as lookup_title, b.type length=6 as type, 
						b.year length=9 as year, compbl(b.imdbID) length=10 as imdbID, 
						scan(b.Genre, 1, ',') length=20 as Genre, b.runtime length=20 from 
						jout.root b;
				quit;

				%if %sysfunc(exist(work.title)) %then
					%do;

						proc sort data=title nodupkey;
							by title;
						run;

						proc append base=ae.omdb data=title force;
						
						proc datasets library=work nolist nodetails;
							delete title;
							run;
						%end;
					%else
						%do;

						data title;
							length title $200 lookup_title $200 type $6 year $9 imdbID $10 Genre $20 
								runtime $20;
							lookup_title="&&lookuptitle&i";
							title="***Title Not Found***";

						proc append base=ae.omdb data=title force;
						proc datasets library=work nolist nodetails;
							delete title;
							run;
					%end;
				%end;
		%end; */
	%MEND getOMDB;

	*initialize dataset with 0 obs to store data returned from OMDB API;

data ae.omdb;
	length title $200 lookup_title $200 type $6 year $9 imdbID $10 Genre $20 
		runtime $20;
	stop;
run;

%getOMDB(type=series, name=seriestitle);
%getOMDB(type=movie, name=title);

proc sql;
     create table viewing3 as 
     select *
     from ae.omdb a, viewing2 b
     where b.seriestitle=a.title or a.title=b.title ;
quit;

data viewing4 ; 
     length rt 8 ; 
     set viewing3;  
     rt=put(scan(runtime,1,' '),8.);
run;    
    
proc summary data=viewing4 nway;
where contentType in('Movie','Series');
     class year_watched genre title;
     var rt;
     output out=sumz (drop=_TYPE_) sum= /autolabel autoname; 
run;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgplot data=WORK.SUMZ;
	heatmap x=year_watched y=Genre / name='HeatMap' discretex colorresponse=rt_Sum 
		colorstat=mean;
	gradlegend 'HeatMap';
run;

ods graphics / reset;


ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgplot data=WORK.SUMZ;
	heatmap x=year_watched y=title / name='HeatMap' discretex colorresponse=rt_Sum 
		colorstat=mean; 
	gradlegend 'HeatMap';
run;

ods graphics / reset;


ods graphics / reset width=6.4in height=4.8in imagemap;

proc sort data=WORK.SUMZ out=_HeatMapTaskData;
	by year_watched;
run;

proc sgplot data=_HeatMapTaskData;
	by year_watched;
	heatmap x=Genre y=title / name='HeatMap' colorresponse=rt_Sum;
	gradlegend 'HeatMap';
run;

ods graphics / reset;

proc datasets library=WORK noprint;
	delete _HeatMapTaskData;
	run;
  quit; 


