***************************************************************************
*
* Name       : splitvar.sas
* Description: Dynamically splits a variable in a SAS dataset on a user-
               specified delimiter, such that the output variables do not 
               exceed 200 character limit
* Input      : inds     = input dataset
               var      = input variable
               outds    = output dataset
               pfx      = output variable                       default = &var
               sfxst    = suffix start number                   default = 1
               dlm      = string delimiter                      default = space
               len      = max length of string                  default = 200
               drop     = drop origin variable (arg var)        default = N (not dropped)
               debug    = adds options mlogic mprint 
                          and retains intermediary datasets     default = N (disabled)
* Output     : variableX ... variableN
* Programmer : Josephine Strange
*
***************************************************************************;
%macro splitvar(inds=,var=,outds=,pfx=&var.,sfxst=1,dlm=" ",len=200,drop=N,debug=N) / des="Splits variables dynamically";

    %if %upcase(&debug.) ^= N %then %do; 
        options mlogic mprint;
    %end;

    ***************************************************************************
    * Step 1 - Find number of iterations/variables
    ***************************************************************************;
    data pre_&outds.00;
        set &inds.;
        * Non-enumerated variable only created when sfxst = 1;
        if &sfxst. = 1 then itera = ceil(length(&var.)/&len.)-2;
        else itera = ceil(length(&var.)/&len.)-1;
    run;

    * Create macro variable holding number of iterations;
    proc sql noprint;
        select max(itera)
            into :n 
        from pre_&outds.00;
    quit;

    %put NOTE: &outds.: Number of enumerated variables: %sysevalf(&n.+1);

    * Free memory if debugging is disabled; 
    %if %upcase(&debug.) = N %then %do;
        proc datasets lib=work noprint;
            delete pre_&outds.00;
        quit; 
    %end; 

    ***************************************************************************
    * Step 2 - Dynamically assign variables
    ***************************************************************************;
    data &outds. (drop= tmp _&var._);
        set &inds.;
        
        * Replace line feed with space;
        _&var._ = compbl(translate(&var.,'20'x,'0A'x));
        
        * Assign variable dynamically;
        if length(_&var._) > &len. then do;
            
            ***************************************************************************
            * Create non-enumerated variable
            ***************************************************************************;
            if &dlm. = " " and &sfxst. = 1 then do;
                &pfx. = strip(substr(_&var._,1,find(_&var._,&dlm.,-&len.)));
                tmp = strip(substr(_&var._,find(_&var._,&dlm.,-&len.)));
            end; 

            * If delimiter is not space, it may be low frequency occurrence;
            else if &dlm. ^= " " and &sfxst. = 1 then do;
                * Delimiter not within substring;
                if not find(tmp,&dlm.,-&len.) then do; 
                    put "NOTE: Delimiter '" &dlm. "' not within substring, delimiter set to space.";
                    &pfx. = strip(substr(_&var._,1,find(_&var._," ",-&len.)));
                    tmp = strip(substr(_&var._,find(_&var._," ",-&len.)+1));
                end;

                * Delimiter within substring;
                else do; 
                    &pfx. = strip(substr(_&var._,1,find(_&var._,&dlm.,-&len.)));
                    tmp = strip(substr(_&var._,find(_&var._,&dlm.,-&len.)+1));
                end;
            end;

            * Cases where suffix start is greater than 1;
            else tmp = strip(_&var._);
           
                
            ***************************************************************************
            * Create enumerated variables
            ***************************************************************************;
            %do i=&sfxst. %to %sysevalf(&sfxst.+&n.);

                * Store remainder in final enumerated variable;
                if &i. = %sysevalf(&sfxst.+&n.) then do; 
                    &&pfx.&i. = strip(tmp); 
                    if length(&pfx.&i.) > &len. then do;
                        put "WAR" "NING: &outds.: The contents of &pfx.&i. exceeds &len. characters.";
                    end;
                end; 

                * Delimiter not within substring; 
                else if not find(tmp,&dlm.,-&len.) then do; 
                    put "NOTE: Delimiter '" &dlm. "' not within substring, delimiter set to space.";
                    &&pfx.&i. = strip(substr(tmp,1,find(tmp," ",-&len.)));
                    tmp = strip(substr(tmp,find(tmp," ",-&len.))); 
                end;

                * Delimiter within substring;
                else do;
                    * Space delimited;
                    if &dlm. = " " then do;
                        &&pfx.&i. = strip(substr(tmp,1,find(tmp,&dlm.,-&len.)));
                        tmp = strip(substr(tmp,find(tmp,&dlm.,-&len.)));
                    end; 

                    * Non-space delimited;
                    else do;
                        &&pfx.&i. = strip(substr(tmp,1,find(tmp,&dlm.,-&len.)+1));
                        tmp = strip(substr(tmp,find(tmp,&dlm.,-&len.)+1));
                        end;
                    end;
                %end;
            end;

        else if &sfxst. = 1 and length(_&var._) < &len. then &pfx. = _&var._;

        * Drop the originator variable if specified;
        %if %upcase(&drop.) ^= N %then %do;
            drop &var.;
        %end; 
    run;

    options nomlogic nomprint;
%mend splitvar;
