#!/usr/local/bin/perl -w
#
# pure perl httpd. (c) Paul Tchistopolskii 1998, 99 ... 2008
#
# http://www.pault.com
#
# Back by popular demand. 
#
# Public domain. I'l appreciate any feedback.
# Especialy ideas how to remove a couple of lines from this file.
#
# Apr.29.1998: v 0.2
#	'Support' for 'POST'. It was useful for debugging uploads.
#
# Nov.27.1998: v 0.1
#       Supports only .htm(l) and .cgi in one directory
#       Not all ENV's are set. No 'index.html'. Only 'GET' yet.
#
#

    use strict; use Socket;

    my $port = 8080;
    my $PERL = '/qub/perl';

    $|=1;

    sub logmsg { print STDERR scalar localtime, ": $$: @_\n"; }

    my %codes = (
    '200', 'OK',
    '201', 'Created',
    '202', 'Accepted',
    '204', 'No Content',
    '301', 'Moved Permanently',
    '302', 'Moved Temporarily',
    '304', 'Not Modified',
    '400', 'Bad Request',
    '401', 'Unauthorized',
    '403', 'Forbidden',
    '404', 'Not Found',
    '500', 'Internal Server Error',
    '501', 'Not Implemented',
    '502', 'Bad Gateway',
    '503', 'Service Unavailable',
    );

    sub logerr ($$) { 
        my ($code, $detail) = @_;
	my $msg = "$code " . $codes{$code};
        logmsg "$detail : $msg";
        print  "HTTP/1.0 $msg\nContent-type: text/html\n\n";
        print  "<I>PurePerlHttpd</I> : $detail : $msg\n";
    }

    sub cat($){
	my $file = shift;
	open IN, "<$file" || return 0;
        my $content = join '', <IN>;	
	close IN;

	print "HTTP/1.0 200 OK\n";
        print "Content-type: text/html\n\n";
	print $content;
	return 1;
    }


    my $tcp = getprotobyname('tcp');
    socket(Server, PF_INET, SOCK_STREAM, $tcp)      || die "socket: $!";
    setsockopt(Server, SOL_SOCKET, SO_REUSEADDR,
                                    pack("l", 1))   || die "setsockopt: $!";
    bind(Server, sockaddr_in($port, INADDR_ANY))    || die "bind: $!";
    listen(Server,SOMAXCONN)                        || die "listen: $!";

    logmsg "server started on port $port";

    my $addr; my @inetaddr;

    for ( ; $addr = accept(Client,Server); close Client) {
	my($undef, $undef, $inetaddr) = unpack('S n a4 x8', $addr);
        @inetaddr = unpack('C4', $inetaddr);

        logmsg "incoming connection from: " , join(".", @inetaddr);

        *STDIN = *Client;
        *STDOUT = *Client;

	$_ = <STDIN>;
        my ($method, $url, $proto, $garbage) = split;

	if ($garbage ne '') { 
		logerr 400, $_;
        } else {
                logmsg "Req: mthd=$method, url=$url, prot=$proto";
                $url =~ s/%([\dA-Fa-f]{2})/chr(hex($1))/eg; # unescape.
                logmsg "Unescaped url: $url";

	        if ( $method ne 'GET') {
			if ( $method ne 'POST' ) {		
				logerr 501, $method;
			} else {
				while ( <STDIN> ) {
					print STDERR $_;
				}

			}
	        } else {

			if ( $url !~ m|.*/([^/]*)$| ) {
				logerr 400, $url;
			} else {
				my $file = $1;

   				$ENV{'REQUEST_URI'}       = $url;
   				$ENV{'SERVER_PROTOCOL'}   = $proto;
				$ENV{'REQUEST_METHOD'}    = $method;
   				$ENV{'REMOTE_ADDR'}       = $inetaddr;

				if ( not -e $file ) {
					logerr 404, $file;
				} else {
					if ( $file =~ m/\.cgi$/ ) {
						logmsg "Executing '$file'";
						my $res = `$PERL $file`; # Win!
						logmsg "Sending results...";
						print "HTTP/1.0 200 OK\n";
						print $res;
					} elsif ( $file =~ m/\.html?$/ ) {
						logmsg "Dumping '$file'";
						cat $file || logerr 500,$file;
					} else {
						logerr 501, $file;
					}
				}
			}
		}
        }
        close STDIN;
        close STDOUT;
    }


