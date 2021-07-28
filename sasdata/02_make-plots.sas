/************************************************************************************************************************************/
/*																																	*/
/* TEAM: OPIOID RESEARCH WORKGROUP																									*/
/* CHANNEL: 22 - TRENDS IN SUBSTANCE USE SECONDARY TO OUD																			*/
/* AUTHOR: MICHAEL MAGUIRE, M.S. | DATA MANAGEMENT ANALYST II																		*/
/* INSTITUTION: UNIVERSITY OF FLORIDA, COLLEGE OF PHARMACY, PHARMACEUTICAL OUTCOMES AND POLICY										*/
/* SUPERVISOR: AMIE GOODIN, MPP, PHD																								*/
/* TEAM MEMBERS: AOLANI CHIRINO, KAYLA SMITH, MIKELA MOLLANAZAR																		*/
/* PROGRAM: 02_make-plots.sas																										*/ 
/*																																	*/
/************************************************************************************************************************************/

/* Create macro variable that contains path to files for filename statement. */

%let path = C:\Users\michaelqmaguire2\Dropbox (UFL)\01_projects\nsduh-extracts\nsduh-extracts\nsduh-extracts-2015-2019\sasdata;

/* Create libname for permanent datasets. */

libname nsduh "&path.";

/* Create macro variable containing variables to plot. */
/* Excluding weight variables and ID variables. */

proc sql noprint;
    select
                name
                    into: vars separated by " "
    from
                dictionary.columns
    where
                libname = "NSDUH" and memname = "NSDUH_2015_2019" and name not in ("ANALWT_C", "VESPR", "VEREP", "YEAR", "QUESTID2");
quit;

/* Output the macro variable to log just to check. */

%put &vars.;

/* Macro that will plot each variable separately on its own page. */

%macro plot ();

/* Setting orientation to landscape so we have more width. */

options orientation = landscape;
ods graphics on / width = 20in length = 10in;

/* Open the PDF destination */

ods pdf file = "&path.\02_make-plots.pdf" startpage = yes;

/* Plot number of records by year */

title "Number of Records by Year";
proc sgplot
	data = nsduh.nsduh_2015_2019;
		vbar year / stat = sum datalabel
		;
run;

/* Initiate macro variable <i> that iterates in %DO loop for each word it encounters in the &vars. macro variable. */

%do i = 1 %to %sysfunc(countw(&vars., " "));

	/* This captures the variable selected in the %DO loop. */

	%let var = %scan(&vars., &i., " ");

		/* Plot the i'th variable. */

		title "Plot of %upcase(&var.) by year";
			proc sgplot
			    data = nsduh.nsduh_2015_2019
			    ;
			        hbar &var.  /   stat = percent
			                        group = year
			        ;
					yaxis type = discrete valueattrs = (size = 6) fitpolicy = none;
					xaxis valueattrs = (size = 6);
			run;
		title;

/* End the do loop. If more words are encountered, %DO returns to the top and continues processing. */

%end;

/* Close the PDF destination */

ods pdf close;

/* End the macro */

%mend plot;

/* Execute the macro. */

%plot;
