/************************************************************************************************************************************/
/*																																	*/
/* TEAM: OPIOID RESEARCH WORKGROUP																									*/
/* CHANNEL: 22 - TRENDS IN SUBSTANCE USE SECONDARY TO OUD																			*/
/* AUTHOR: MICHAEL MAGUIRE, M.S. | DATA MANAGEMENT ANALYST II																		*/
/* INSTITUTION: UNIVERSITY OF FLORIDA, COLLEGE OF PHARMACY, PHARMACEUTICAL OUTCOMES AND POLICY										*/
/* SUPERVISOR: AMIE GOODIN, MPP, PHD																								*/
/* TEAM MEMBERS: AOLANI CHIRINO, KAYLA SMITH, MIKELA MOLLANAZAR																		*/
/* PROGRAM: 01_import-and-clean.sas																									*/ 
/*																																	*/
/************************************************************************************************************************************/

/* Create macro variable that contains path to files for filename statement. */

%let path = C:\Users\michaelqmaguire2\Dropbox (UFL)\01_projects\nsduh-extracts\nsduh-extracts\nsduh-extracts-2015-2019\sasdata;

/* Create libname for permanent datasets. */

libname nsduh "&path.";
libname nsduhxl xlsx "&path.\nsduh_2015_2019.xlsx";

/* Write out separate filename for each SAS transport file. */

filename nsduh15 "&path.\NSDUH_2015-data-sas.stc";
filename nsduh16 "&path.\NSDUH_2016-data-sas.stc";
filename nsduh17 "&path.\NSDUH_2017-data-sas.stc";
filename nsduh18 "&path.\NSDUH_2018-data-sas.stc";
filename nsduh19 "&path.\NSDUH_2019-data-sas.stc";

/* Macro to import each transport file. */

%macro tp_imp ();

/* Begin %DO loop that loops from 15 to 19. */

%do i = 15 %to 19;

	/* Import the SAS transport files into the WORK directory using the FILENAME statements made above. */

	proc cimport library = work infile = nsduh&i.;
	run;

/* End the %DO loop. If the final number (19) hasn't been reach, return to to the top and repeat the CIMPORT procedure. */

%end;

%mend tp_imp;

/* Execute macro. */

%tp_imp;

/* Bring in the text document that I copied from KS's word document. */

data work.requested_vars;
	infile "&path\requested-variables.txt";
	input variable $1000.;
	length var_name $50.;

		/* Create <variable_of_interest>, which represents the variable name and not the label in Kayla's document. */
		
		variable_of_interest = scan(variable, 1, "-");

run;

proc sql;
	insert into 	work.requested_vars
		set			variable_of_interest = "QUESTID2";
quit;

/* PNRNMLAS1 exists in 2016-2019, but not in 2015. They simply renamed it from PNRNMLAST to PNRNMLAS1. */

data work.requested_vars2015;
	set work.requested_vars;

		if variable_of_interest = "PNRNMLAS1" then variable_of_interest = "PNRNMLAST";
			else variable_of_interest = variable_of_interest;

run;

/* Create a macro variable containing the NSDUH 2016-2019 variable names separated by commas. */

proc sql noprint;
	select
				distinct variable_of_interest
					into: vars_non2015 separated by ", "
	from
				requested_vars;
quit;

/* Create a macro variable containing the NSDUH 2015 variable names separated by commas. */

proc sql noprint;
	select
				distinct variable_of_interest
					into :vars_2015 separated by ", "
	from
				requested_vars2015;
quit;

/* Output macro variables to log and examine. */

%put &vars_non2015.;
%put &vars_2015.;

/* Extract the names of the datasets in the WORK directory after being imported with macro above. */

proc sql noprint;
	select
				distinct memname
					into: datasets separated by " "
	from
				dictionary.columns
	where
				libname = "WORK" and substr(memname, 1, 3) = "PUF";
quit;

/* Output macro variable containing dataset names to log. */

%put &datasets.;

/* Set these options to debug/troubleshoot macro. */

options symbolgen;
options mlogic;

/* Macro to iteratively select desired variables from each dataset. */

%macro subset ();

/* This creates a local macro variable named <i> that counts each instance of the %DO loop based on the number of spaces in the &datasets. macro variable. */

%do i = 1 %to %sysfunc(countw(&datasets., " "));

	/* Wherever we are in the loop, scan the macro variable &datasets. for the i'th dataset based on the space delimiter. */

	%let dsn = %scan(&datasets., &i., " ");

		/* Remember that 2015 had old variable name that we need to account for. Will use the 2015 macro variable containing 2015 variable names. */

		%if &dsn. = PUF2015_021518 %then %do;
			proc sql;
				create table	work.copy_&dsn. as
					select
								&vars_2015.
					from
								&dsn.;
			quit;
		%end;

		/* If it's not the 2015 dataset, use the 2016-2019 macro variable containing the variable names. */

		%else %do;
			proc sql;
				create table	work.copy_&dsn. as
					select
								&vars_non2015.
					from
								&dsn.;
			quit;
		%end;

/* This is the %END statement for the %DO loop. If there are more words to process, it will increment the <i> macro variable by 1 and repeat the procedure for the next word. If there are no more, the macro will stop processing. */

%end;

/* End the macro. */

%mend subset;

/* Execute the macro. */

%subset;

/* Combine all the datasets and conduct final cleaning. */

data work.nsduh_combined;
	set copy_: indsname = dataset;

		/* Create variable <origin> that represents which dataset the observation originated from. */
		/* INDSNAME tracks where the observation came from and stores it in a macro (?) variable. It stores it in a two-level name, e.g. (SASHELP.CARS). */

		origin = scan(dataset, 2, ".");

		/* Extract just the year portion of the origin column. */

		YEAR = substr(compress(origin, , "kd"), 1, 4);

		/* Since that variable was renamed, we need to combine the columns. */

		PNRNMLAS1_C = coalesce(pnrnmlas1, pnrnmlast);

		/* Create a new variable that represents the coalesced AND formatted column. */
		/* Specifically, if it comes from the 2015 dataset, apply the 2015 format (though this may not matter). */

		if origin = "COPY_PUF2015_021518" then do;
			PNRNMLAS1_CF = put(pnrnmlas1_c, pnrnmlastfmt.);
		end;

			/* Otherwise, apply the 2016-2019 formats. */

			else do;
				PNRNMLAS1_CF = put(pnrnmlas1_c, pnrnmlas1fmt.);
			end;

run;

/* Check to ensure we have valid years. */

proc freq
	data = work.nsduh_combined;
		tables year;
run;

/* Checking new variable creation to make sure that variables were classified correctly. */

proc freq
	data = work.nsduh_combined;
		tables pnrnmlast * pnrnmlas1_cf * origin / list;
		tables pnrnmlas1 * pnrnmlas1_cf * origin / list;
run;

/* Write out permanent dataset. */

options compress = yes;

data nsduh.nsduh_2015_2019;
	set nsduh.nsduh_2015_2019;
	retain QUESTID2;
	set work.nsduh_combined (drop = origin pnrnmlast pnrnmlas1 pnrnmlas1_c);
run;

/* Write out excel file per Amie's request. */

data nsduhxl.nsduh_2015_2019;
	set nsduh.nsduh_2015_2019;
		pnrnmlas1_cf = scan(pnrnmlas1_cf, 1, "-");
run;

/* Exporting CSV with labels because xlsx engine doesn't allow them (?) */

proc export
	data = nsduh.nsduh_2015_2019
		outfile = "&path.\nsduh_2015_2019_labels.csv"
		dbms = csv
		replace;
		label;
run;

/* Proceed to 02_make-plots.sas */

proc sql;
	select
				distinct pnrnmlas1_cf
	from
				nsduh.nsduh_2015_2019;
quit;

