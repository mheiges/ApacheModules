package Apache::Stater;

# emit Apache state from post_config hook on startup

# http://modperlbook.org/html/25-2-New-Apache-Phases-and-Corresponding-PerlHandlers.html

# /etc/httpd/lib/perl/Apache/Stater.pm

# in conf.d/perl.conf
#   PerlRequire conf/startup.pl
#   PerlModule            Apache::Stater
#   PerlPostConfigHandler Apache::Stater::post_config
#   PerlOpenLogsHandler   Apache::Stater::open_logs

use strict;
use warnings;

use Apache2::Log ();
use Apache2::ServerUtil ();

use Fcntl qw(:flock);
use File::Spec::Functions;

use Apache2::Const -compile => 'OK';
use Apache2::ServerRec;

use Data::Dumper;

my $log_path = catfile Apache2::ServerUtil::server_root,
    "logs", "startup_log";
my $log_fh;

sub open_logs {
    my ($conf_pool, $log_pool, $temp_pool, $s) = @_;

    $s->warn("opening the log file: $log_path");
    open $log_fh, ">>$log_path" or die "can't open $log_path: $!";
    my $oldfh = select($log_fh); $| = 1; select($oldfh);

    say("process $$ is born to reproduce");
    return Apache2::Const::OK;
}

sub post_config {
    my ($conf_pool, $log_pool, $temp_pool, $s) = @_;
    say("configuration is completed");

  my @handlers = @{ $s->get_handlers('PerlChildExitHandler') || []};
  say(Dumper @handlers);
    my $cnt = Apache2::ServerUtil::restart_count();
    if ($cnt > 1) {
      say("Restart count: $cnt");
      say("Parent host: " . $s->server_hostname());
  
      my $vhosts = 0;
      my $server = Apache2::ServerUtil->server;
      for (my $v = $server->next; $v; $v = $v->next) {
        say ($v->server_hostname());
        $vhosts++;
      }
      say ("There are $vhosts virtual hosts");
    }
    return Apache2::Const::OK;
}

sub say {
    my ($caller) = (caller(1))[3] =~ /([^:]+)$/;
    if (defined $log_fh) {
        flock $log_fh, LOCK_EX;
        printf $log_fh "[%s] - %-11s: %s\n", 
            scalar(localtime), $caller, $_[0];
        flock $log_fh, LOCK_UN;
    }
    else {
        # when the log file is not open
        warn __PACKAGE__ . " says: $_[0]\n";
    }
}

1;