#!/usr/bin/perl
# File makedll.pl created by Joshua Wills at 12:45:07 on Fri Sep 19 2003. 


my $curdir = ".";
if ($ARGV[0]) {
    $curdir = $ARGV[0];
}

#constants
my $INT = 0;
my $VOID = 1;
my $STRING = 2;

#functions to ignore in parsing ecmdClientCapi.H
my @ignores = qw( ecmdLoadDll ecmdUnloadDll ecmdCommandArgs ecmdQueryTargetConfigured);
my $ignore_re = join '|', @ignores;

my @dont_flush_sdcache = qw( Query Cache Output Error Spy );
my $dont_flush_sdcache_re = join '|', @dont_flush_sdcache;
 
my $printout;
my @enumtable;

open IN, "${curdir}/ecmdClientCapi.H" or die "Could not find ecmdClientCapi.H: $!\n";

open OUT, ">${curdir}/ecmdDllCapi.H" or die $!;
print OUT "/* The following has been auto-generated by makedll.pl */\n";

print OUT "#ifndef ecmdDllCapi_H\n";
print OUT "#define ecmdDllCapi_H\n\n";

print OUT "#include <inttypes.h>\n";
print OUT "#include <vector>\n";
print OUT "#include <string>\n";
print OUT "#include <ecmdStructs.H>\n";
print OUT "#include <ecmdReturnCodes.H>\n";
print OUT "#include <ecmdDataBuffer.H>\n\n\n";

print OUT "extern \"C\" {\n\n";

print OUT "/* Dll Common load function - verifies version */\n";
print OUT "int dllLoadDll (const char * i_version);\n";
print OUT "/* Dll Specific load function - used by Cronus/GFW to init variables/object models*/\n";
print OUT "int dllInitDll ();\n\n";
print OUT "/* Dll Common unload function */\n";
print OUT "int dllUnloadDll ();\n";
print OUT "/* Dll Specific unload function - deallocates variables/object models*/\n";
print OUT "int dllFreeDll();\n\n";
print OUT "/* Dll Common Command Line Args Function*/\n";
print OUT "int dllCommonCommandArgs(int*  io_argc, char** io_argv[]);\n";
print OUT "/* Dll Specific Command Line Args Function*/\n";
print OUT "int dllSpecificCommandArgs(int*  io_argc, char** io_argv[]);\n\n";


#parse file spec'd by $ARGV[0]
while (<IN>) {

    if (/^(int|std::string|void)/) {
	
	next if (/$ignore_re/o);

	my $type_flag = $INT;
	$type_flag = $VOID if (/^void/);
	$type_flag = $STRING if (/^std::string/);

	chomp; chop;  
	my ($func, $args) = split /\(|\)/ , $_;

	my ($type, $funcname) = split /\s+/, $func;
	my @argnames = split /,/ , $args;

        #remove the default initializations
        foreach my $i (0..$#argnames) {
            if ($argnames[$i] =~ /=/) {
              $argnames[$i] =~ s/=.*//;
            }
        }

        $" = ",";
        $printout .= "$type $funcname(@argnames) {\n\n";

	
	$printout .= "  $type rc;\n\n" unless ($type_flag == $VOID);


	unless (/$dont_flush_sdcache_re/o) {
	    $printout .= "  int flushrc = ecmdFlushRingCache();\n";
	    $printout .= "  if (flushrc) {\n";
	    if ($type_flag == $STRING) {
		$printout .= "     return ecmdGetErrorMsg(flushrc);\n";
	    }
	    elsif ($type_flag == $INT) {
		$printout .= "     return flushrc;\n";
	    }
	    else { #type is VOID
		$printout .= "     return;\n";
	    }

	    $printout .= "  }\n\n";
	}
	
	$printout .= "#ifdef ECMD_STATIC_FUNCTIONS\n\n";

	$printout .= "  rc = " unless ($type_flag == $VOID);

        my $enumname;

        if ($funcname =~ /ecmd/) {

           $funcname =~ s/ecmd//;

           $enumname = "ECMD_".uc($funcname);

           $funcname = "dll".$funcname;
        }
        else {

           $enumname = "ECMD_".uc($funcname);
           $funcname = "dll".ucfirst($funcname);
        }

        print OUT "$type $funcname(@argnames); \n\n";
	$" = " ";
       
	if ($type_flag == $VOID) {
	    $printout .= "  ";
	}

	$printout .= $funcname . "(";

	my $argstring;
	my $typestring;
	foreach my $curarg (@argnames) {

	    my @argsplit = split /\s+/, $curarg;

	    my @typeargs = @argsplit[0..$#argsplit-1];
	    $tmptypestring = "@typeargs";

	    my $tmparg = $argsplit[-1];
	    if ($tmparg =~ /\[\]$/) {
		chop $tmparg; chop $tmparg;
		$tmptypestring .= "[]";
	    }

	    $typestring .= $tmptypestring . ", ";
	    $argstring .= $tmparg . ", ";
	}

	chop ($typestring, $argstring);
	chop ($typestring, $argstring);

	$printout .= $argstring . ");\n\n";
	    
	$printout .= "#else\n\n";
	
	
	$printout .= "  if (dlHandle == NULL) {\n";
	if ($type_flag == $STRING) {
	    $printout .= "     return \"ECMD_DLL_UNINITIALIZED\";\n";
	}
	elsif ($type_flag == $INT) {
	    $printout .= "     return ECMD_DLL_UNINITIALIZED;\n";
	}
	else { #type is VOID
	    $printout .= "     return;\n";
	}

	$printout .= "  }\n\n";

	$printout .= "  if (DllFnTable[$enumname] == NULL) {\n";
	$printout .= "     DllFnTable[$enumname] = (void*)dlsym(dlHandle, \"$funcname\");\n";

	$printout .= "     if (DllFnTable[$enumname] == NULL) {\n";
	if ($type_flag == $STRING) {
	    $printout .= "       return \"ECMD_DLL_INVALID\";\n";
	}
	elsif ($type_flag == $INT) {
	    $printout .= "       return ECMD_DLL_INVALID;\n";
	}
	else { #type is VOID
	    $printout .= "       return;\n";
	}
	$printout .= "     }\n";
	
	$printout .= "  }\n\n";

	$printout .= "  $type (*Function)($typestring) = \n";
	$printout .= "      ($type(*)($typestring))DllFnTable[$enumname];\n\n";

	$printout .= "  rc = " unless ($type_flag == $VOID);
	$printout .= "   (*Function)($argstring);\n\n" ;
	
	$printout .= "#endif\n\n";

	$printout .= "  return rc;\n\n" unless ($type_flag == $VOID);

	$printout .= "}\n\n";

	push @enumtable, $enumname;
    }

}
close IN;

print OUT "} //extern C\n\n";
print OUT "#endif\n";
print OUT "/* The previous has been auto-generated by makedll.pl */\n";

close OUT;  #ecmdDllCapi.H

open OUT, ">${curdir}/ecmdClientCapiFunc.C" or die $!;

print OUT "/* The following has been auto-generated by makedll.pl */\n\n";
print OUT "#include <ecmdClientCapi.H>\n";
print OUT "#include <ecmdDllCapi.H>\n\n\n";
print OUT "#ifndef ECMD_STATIC_FUNCTIONS\n";
print OUT "\n#include <dlfcn.h>\n\n";


push @enumtable, "ECMD_COMMANDARGS"; # This function is handled specially because it is renamed on the other side

push @enumtable, "ECMD_NUMFUNCTIONS";
$" = ",\n";
print OUT "typedef enum {\n@enumtable\n} ecmdFunctionIndex_t;\n\n";
$" = " ";

print OUT "void * dlHandle = NULL;\n";
print OUT "void * DllFnTable[ECMD_NUMFUNCTIONS];\n";

print OUT "#endif\n\n\n";

print OUT $printout;

print OUT "/* The previous has been auto-generated by makedll.pl */\n";

close OUT;  #ecmdClientCapiFunc.C
