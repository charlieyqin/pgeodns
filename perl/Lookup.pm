package Lookup;
use strict;
use DB_File;
use Net::DNS;
use Socket;
use Exporter;
use vars qw(@ISA @EXPORT_OK %db);
@ISA = qw(Exporter);
@EXPORT_OK = qw(lookup);


my $last_sync = 0;
my $tied      = 0;
sub retie {
  untie %db;
  tie %db, "DB_File", "db/ip_country"
    or die "Cannot open file 'db/ip_country': $!\n";
  $last_sync = time;
  $tied = 1;

}

sub lookup {
  my ($ip, $force) = @_;
  retie unless $tied;
  if ($force
      or !$db{$ip}
      or (time-(split ":", $db{$ip})[0] > 86400*31)) {
    #warn "Looking up $ip";
    my $name = lc ip2name($ip);
    #warn "name: $name\n";
    $name =~ s/.*\.([^.]+)$/$1/;
    $name = "us"  # blatant assumtions at play
      if $name =~ m/^(com|net|org|edu|mil|gov)$/;
    #warn "name2: $name";
    $db{$ip} = time. ":$name";
    retie if (time-$last_sync > 60);

  }
  (split ":", $db{$ip})[1]
}


my $res = Net::DNS::Resolver->new;

sub ip2name {
  my ($ip, $timeout) = @_;

  $timeout ||= 3;

  my $pkt;

  eval {
    local $SIG{ALRM} = sub { die "TIMEOUT\n" };
    alarm($timeout);
    $pkt = $res->query($ip);
    alarm(0);
  };
  if ($@ =~ /TIMEOUT/) {
    print "got dns timeout for $ip\n";
  }

  $pkt or return "";

  my @ans = $pkt->answer;

  foreach my $rr (@ans) {
    return lc $rr->ptrdname if $rr->type eq 'PTR';
    return lc $rr->name if  $rr->type eq 'A';
  }

  "";
}


END {
  untie %db;
} 

1;