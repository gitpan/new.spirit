#!/usr/local/perl/5.004_04/bin/perl
#!/usr/local/perl/5.6.0/bin/perl
#!/usr/local/perl/5.005_03/bin/perl

#---------------------------------------------------------------------
# This program checks Perl code for validity. Perl syntax errors and
# pragma constraint violations are reported. It is designed to be
# called by another process using open2() to send chunks of Perl
# code to be checked and recieving the status of the validation.
#
# Perl code is read from STDIN this way:
#	0. Line		what to do: 'check' or 'execute $filename'
#			check	:   only syntax checking
#			execute :   full execution, write output
#				    to $filename
#	1. Line		Directory, to chdir() to befor evaluating
#			the Perl code. If this line is empty,
#			the program exits.
#	2. Line		Directory to use for temp. files
#	3. Line		A delimiter string. This string marks the
#			end of the Perl code, sent after this line.
#			The Perl code must not contain this delimiter
#			string itself.
#	4. Line		Perl code
#	...		  - " -
#	n. Line		  - " -
#	n+1. Line	The delimiter string from the third line.
#
# Validation status is reported to STDOUT this way:
#	1. Line		A delimiter string. This string marks the
#			end of the error messages, sent after this line.
#	2. Line		Perl error messages
#	...			- " -
#	n. Line			- " -
#	n+1. Line	The delimiter string from the first line.
#
# It is possible to send multiple chunks of code, using the input
# protocol stated above. If the first line of the request is
# empty, the program exits.
#
# Note:
#	Due to limitation of the Perl compiler, 'use strict' violations
#	are reported only one time per process, so subsequent usage
#	(even in a new chunk of code) of the same non declared variables
#	is not reported.
#
# Example:
#	This input stream:
#		/www/cgi-bin
#		/tmp
#		__DELIMITER__
#		use strict;
#		$foo=42;
#		if bar foo;
#		__DELIMITER__
#		[empty line]
#
#	results in this output stream:
#		__DELIMITER__
#		Global symbol "foo" requires explicit package name \
#		at (eval 1) line 3, <STDIN> chunk 6.
#		syntax error at (eval 1) line 3, near "if bar foo"
#		__DELIMITER__
#
#---------------------------------------------------------------------

use strict;
use Cwd;
use Carp;
use FileHandle;

main: {
	$| = 1;
	$SIG{__WARN__} = \&catch_warnings;
	$SIG{__DIE__}  = undef;
	perlcheck_loop();
}

sub perlcheck_loop {
	writelog ("started");
	while ( 1 ) {
		# first: read what to do
		my $what = <STDIN>;
		chomp $what;
		
		last if $what eq '';
		if ( $what !~ /^(check|execute)/ ) {
			print STDERR "unknown action: $what\n";
			last;
		}

		# then read the directory, where the Perl code
		# should be executed
	
		my $execute_dir = <STDIN>;
		chomp $execute_dir;

		last if $execute_dir eq '';
		
		# now read the temp dir
		
		my $temp_dir = <STDIN>;
		chomp $temp_dir;

		last if $temp_dir eq '';

		# now read the delimiter which marks the end of the
		# perl code to be checked
	
		my $delimiter = <STDIN>;
		chomp $delimiter;

		last if $delimiter eq '';

		# now read the Perl code
		my $perl_code;
		perlcode: while (<STDIN>) {
			chomp;
			last perlcode if $_ eq $delimiter;
			$perl_code .= "$_\n";
		}

		# check the Perl code and write possible internal errors
		# to $result_file

		my $error;
		if ( $what eq 'check' ) {
			$error = perlcheck (
				$execute_dir,
				$temp_dir,
				\$perl_code
			);
		} else {
			my ($filename) = $what =~ /^execute\s+(.*)/;
			$error = perlexecute (
				$filename,
				$execute_dir,
				$temp_dir,
				\$perl_code
			);
		}
			

		my $delimiter = "__PERLCHECK_REQUEST_FINISHED__";
		while ( $error =~ /$delimiter/ ) {
			$delimiter .= $$;
		}

		print "$delimiter\n";

		if ( $error ) {
			print "$error\n";
		}

		print "$delimiter\n";
	}
}

sub perlcheck {
	my ($dir, $temp_dir, $perl_sref) = @_;

	# eventually change to another directory

	my $cwd_dir = cwd();
	if ( $dir ) {
		chdir $dir or return "Can't chdir to '$dir'";
	}

	# some CIPP specific error handler stuff

	$CIPP_Exec::_cipp_in_execute = 1;
	$CIPP_Exec::_cipp_no_http = 1;

	# disable BEGIN and END blocks,
	# they'll be executed inside our eval, but don't
	# want any code to execute.
	
	# (dont nuke CIPP BEGIN blocks für cipp_back_prod_path
	#  and library path addition)
	$$perl_sref =~ s/BEGIN\s*\{([^\#\$])/{$1/gs;
	$$perl_sref =~ s/END\s*\{/{/gs;

	writelog ($$perl_sref);

	# evaluate Perl code and reset error handler
	my $error = eval_perl_code ($perl_sref);

#	writelog ($error);

	# change to old directory

	chdir $cwd_dir;

	return $error;
}

sub perlexecute {
	my ($catch_file, $dir, $temp_dir, $perl_sref) = @_;

	writelog ("perlexecute request started");

	# eventually change to another directory
	writelog ("cd $dir");
	my $cwd_dir = cwd();
	if ( $dir ) {
		chdir $dir or return "Can't chdir to '$dir'";
	}

	# redirect STDOUT
	writelog ("save STDOUT");
	
	if ( ! open (SAVESTDOUT, ">&STDOUT") ) {
		writelog ("error duping STDOUT");
		chdir $cwd_dir;
		return "can't dup STDOUT";
	}

	writelog ("close STDOUT");

	close STDOUT;

	writelog ("open STDOUT > $catch_file");

	if ( ! open (STDOUT, "> $catch_file") ) {
		open (STDOUT, ">&SAVESTDOUT");
		close SAVESTDOUT;
		chdir $cwd_dir;
		return "Can't write '$catch_file'";
	}

	# some CIPP specific error handler stuff
	$CIPP_Exec::_cipp_in_execute = 1;
	$CIPP_Exec::_cipp_no_http = 1;

	# evaluate Perl code and reset error handler
	writelog ("execute perl code");
	my $error = exec_perl_code ($perl_sref);

	# change to old directory
	writelog ("cd $cwd_dir");
	chdir $cwd_dir;

	# restore STDOUT
	writelog ("restore STDOUT");
	close STDOUT;
	open (STDOUT, ">&SAVESTDOUT")
		or crash("Can't restore STDOUT");
	close SAVESTDOUT;

	writelog ("request finished");

	return $error;
}

sub crash {
	my ($msg) = @_;
	
	writelog ($msg);

	exit 1;
}

sub writelog {
	my ($msg) = @_;
	return;

	my $date = scalar(localtime(time));
	open (LOG, "> /tmp/perlcheck.log");
	print LOG "$date $$\t$msg\n";
	close LOG;
	
	1;
}

{
	my $__CATCHED__WARNINGS__;

	sub eval_perl_code {
		my ($__PERL_CODE_SREF__) = @_;
	
		$__CATCHED__WARNINGS__='';
		no strict;
		eval "return; ".$$__PERL_CODE_SREF__;
	
		return $__CATCHED__WARNINGS__.$@;
	}

	sub exec_perl_code {
		my ($__PERL_CODE_SREF__) = @_;

		$__CATCHED__WARNINGS__='';
		no strict;
		eval $$__PERL_CODE_SREF__;
	
		return $__CATCHED__WARNINGS__.$@;
	}
	
	sub catch_warnings {
		$__CATCHED__WARNINGS__.=$_[0];
	}
}

