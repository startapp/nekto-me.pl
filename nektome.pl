#!/usr/bin/perl

use Socket;
use Data::Dumper;

$DATE=`date +%d.%m.%y\_%H:%M:%S`;
chomp $DATE;
$LOGFNAME="NektoME_LOGS/$DATE";
mkdir 'NektoME_LOGS/' unless -d 'NektoME_LOGS';
open LOG, '>', $LOGFNAME;
binmode(LOG, ':unix');
print "Диалог сохранен в $LOGFNAME\n";

sub err {
	die @_;
}

sub sexit {
	our $my_id;
	our $opp_id;
	print LOG "OUT: <Отключился>\n";
	req("QUIT $my_id $opp_id");
	close LOG;
	exit;
}

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
	our $prefs;
	socket(SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
	connect(SOCK, sockaddr_in(80, inet_aton('nekto.me')));
	open($hf, "headers.txt");
	$reqlength=(length $req);
	while($l = <$hf>){
		$l=~s/\$CONTLEN/$reqlength/g;
		$l=~s/\$PREFS/$prefs/g;
		send(SOCK, $l, 0);
	}
	send(SOCK, "$req\n", 0);
	my $resp;
	while($l=<SOCK>){
		if($l=~/^Content\-Length\:/){
			$clen = int(substr($l, 16));
			<SOCK>;
			read(SOCK, $resp, $clen);
			last;
		}
	}
	if($resp=~/^ERR/){err('Session error, request: '.$req);}
	close(SOCK);
	return $resp;
}

sub prefs {
	print "Введите свои предпочтания:\n";
	print "Ваш пол: \n\t1) Мужской\n\t2) Женский\n(1)> ";
	$mg = <>;
	chomp($mg);
	print "Вы хотите пообщаться с: \n\t1) Мужчиной\n\t2) Женщиной\n(1)> ";
	$yg = <>;
	chomp($yg);
	print "Ваш возраст: \n\t1) <=17\n\t2) 18..21\n\t3) 22..25\n\t4) 26..35\n\t5) >35\n(1)> ";
	$ma = <>;
	chomp($ma);
	print "Возраст желаемого собеседника: \n\t1) <=17\n\t2) 18..21\n\t3) 22..25\n\t4) 26..35\n\t5) >35\n(1)> ";
	$ya = <>;
	chomp($ya);
	print "Я учту, но ничего не обещаю ;-)\n\n";
	return "$mg:$yg:$ma:$ya";
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
				$opp_id=substr($resp, 5);
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
our $prefs=prefs;
init;
print "Ваш id: $my_id\nid собеседника: $opp_id\n";

our $run = -1;

if(our $kpid=fork){
	while(1){
		if($run!=-1){exit$run;}
		my $resp=req("TYPE $my_id $opp_id\n0");
		my $code=substr($resp, 0, 4);
		if($code=~/MESS/){
		my $mesg=substr($resp, 5);
			print LOG "IN: $mesg\n";
			print "\nВам пишут: $mesg\n> ";
		} else {
			if($code=~/QUIT/){
				print LOG "IN: <Отключился>\n";
				print "\nСобеседник отключился.\n\nДля выхода пишем /quit.\n";
				req("QUIT $my_id, $opp_id");
				$run=0;
				last;
			}
			flush LOG;
		}
	}
} else {
	while(1){
		print "> ";
		$msg = <>;
		if($run!=-1){exit$run;}
		chomp $msg;
		if($msg=~/^$/){next;};
		if($msg=~/^\/quit$/){$run=0;sexit;};
		if($msg=~/^\/stat$/){print req('STAT')."\n"; next;};
		req("MESS $my_id, $opp_id, $msg");
		print "Ваше сообщение отправлено.\n";
		print LOG "OUT: $msg\n";
	}
}

0;

