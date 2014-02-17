#!/usr/bin/perl

use Socket;
use Data::Dumper;

$DATE=`date +%d.%m.%y\_%H:%M:%S`;
chomp $DATE;
$LOGFNAME="NektoME_LOGS/$DATE";
mkdir 'NektoME_LOGS/' unless -d 'NektoME_LOGS';
open LOG, '>', $LOGFNAME;
print "Диалог сохранен в $LOGFNAME\n";

sub err {
	die @_;
}


sub sexit {
	our $my_id;
	our $opp_id;
	our $RUN;
	print "\nEXIT.\n";
	print LOG "OUT: <Отключился>\n";
	req("QUIT $my_id $opp_id");
	close LOG;
	$RUN=0;
	exit(0);
}

$SIG{INT} = \&sexit;
$SIG{HUP} = \&sexit;

#Генератор идентификатора.
sub random_id {
	my $random_string;
	my @chars=('0'..'9');
	for(my $i = 0; $i < 16; $i++){
		$random_string .= $chars[int(rand(9))];
	}
	return $random_string;
}

#Отправляет запросы к серверу nekto.me.
sub req {
	my ($req) = $_[0];
	socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
	connect(SOCK, sockaddr_in(80, inet_aton('nekto.me')));
#	print "REQ: $req\n";
	open($hf, "headertmpl.txt");
	$reqlength=(length $req);
#	print "LENGTH: $reqlength\n";
	while($l = <$hf>){$l=~s/\$CONTLEN/$reqlength/g; send(SOCK, $l, 0);}
	send(SOCK, "$req\n", 0);
#	@___resp=<SOCK>;
#	$__resp=join '',@___resp;
#	$__resp=~s/\r//g;
#	@_resp=split "\n\n", $__resp;
#	$resp=$_resp[1];
	my $resp;
	while($l=<SOCK>){
#		print $l;
		if($l=~/^Content\-Length\:/){
			$clen = int(substr($l, 16));
			<SOCK>;
			read(SOCK, $resp, $clen);
			last;
		}
	}
	if($resp=~/^ERR/){err('Session error, request: '.$req);}
#	print $resp."\n";
	close(SOCK);
	return $resp;
}

#Подключение..
sub init {
	our $my_id;
	our $opp_id;
	my $req="INIT $my_id ";
	print "Ждем собеседника.\n";
	while(1){
		$resp = req($req);
		sleep(1);
		if($resp=~/^INIT/){
			$opp_id=substr($resp, 5);
			print " Ок\n";
			last;
		} else {
			if($resp=~/^WAIT/){
#				print "$resp\n";
				$opp_id=substr($resp, 5);
#				print "$my_id\n";
#				print "$opp_id\n";
				$req="INIT $my_id $opp_id";
			} else {
				if($resp=~/^QUIT/) {
				print "No carrier.dctgbpltw.\n";
				} else {
					err("Unknown response from server: $resp");}
				}
			}
		}
}

#Переменные, необходимые для взаимодействия:
our $my_id=random_id; #Мой id
our $opp_id=''; #id собеседника
print "Nekto.ME CLI\n";

init;
print "Ваш id: $my_id\nid собеседника: $opp_id\n";

our $RUN=-1;

if(fork==0){
	while(1){
		if($RUN!=-1){exit $RUN;};
		my $resp=req("TYPE $my_id $opp_id\n0");
		my $code=substr($resp, 0, 4);
		if($code=~/MESS/){
		my $mesg=substr($resp, 5);
			print LOG 'IN: $msg\n';
			print "\nВам пишут: $mesg\n> ";
		} else {
			if($code=~/QUIT/){
				print LOG 'IN: <Отключился>\n';
				req("QUIT $my_id, $opp_id");
				sexit;
			}
		}
		sleep(1);
	}
} else {
	while(1){
		if($RUN!=-1){exit $RUN;};
		print "> ";
		$msg = <>;
#		$msg=join '',@msg;
		req("MESS $my_id, $opp_id, $msg");
		print LOG "OUT: $msg\n";
	}
}

0;

