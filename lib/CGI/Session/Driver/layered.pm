package CGI::Session::Driver::layered;

use strict;
use warnings;
use base qw(CGI::Session::Driver);

use Time::HiRes qw(time);

our $VERSION = '0.5';

=head1 NAME 

CGI::Session::Driver::layered - Use multiple layered drivers

=head1 SYNOPSIS

 use CGI::Session;
 
 my $session = CGI::Session->new("driver:layered", $sessionId, { Layers => [
   {
     Driver    => 'file',
     Directory => '/tmp/foo',
   },
   {
     Driver => 'postgresql'
     table  => 'websessions',
     handle => $dbh
   }
 ]});

=head1 DESCRIPTION

CGI::Session::Driver::Layered provides a interface for using multple drivers
to store sessions.  Each session is stored in all the configured drivers. When
fetching a session, the driver with the most recent copy of the session is used.
The drivers are searched in the order they were configured.

=head1 OPTIONS

Unlike most drivers for CGI::Session, this driver requires options to
function. The driver args must has a layers field, which is an array ref of
hash references. Each hash reference should contain the driver name under
the key C<driver>, and the rest of the arguments for that driver. The order
of the layers argument is the order that the layer will check during a
retrieve.

=cut

sub init {
    my $self = shift;

    my $ret = $self->SUPER::init(@_);
    
    $self->{drivers} = [];
    
    foreach my $layer (@{$self->{Layers}}) {
      # make a local copy of the driver, so we can delete it from the args
      # we pass to Driver->new()
      local $layer->{Driver} = $layer->{Driver};
      
      my $driver = delete $layer->{Driver} || return $self->set_error("A layer was missing a driver."); 
      
      require "CGI/Session/Driver/$driver.pm";
      
      push(@{$self->{drivers}}, "CGI::Session::Driver::$driver"->new($layer));
    }
    
    return $self;
}


sub store {
    my ($self, $sid, $datastr) = @_;
    
    $datastr = time . ':' . $datastr;
    
    my $ret = 1;
    
    foreach my $driver (@{$self->{drivers}}) {
      $driver->store($sid, $datastr) || do { $ret = 0 };
    }
    
    return $ret if $ret;
    return;
}

sub retrieve {
    my ($self, $sid) = @_;
    
    # atime at 0, data at 1
    my $latest = [0, ''];
    
    foreach my $driver (@{$self->{drivers}}) {
      if (my $str = $driver->retrieve($sid)) {
        my ($atime, $data) = split(m/:/, $str, 2);
        
        if ($atime > $latest->[0]) {
          $latest = [$atime, $data];
        }
      }
    }
    
    return $latest->[1];
}

sub remove {
    my ($self, $sid) = @_;

    my $ret = 1;
    
    foreach my $driver (@{$self->{drivers}}) {
      if (!$driver->delete($sid)) {
        $ret = 0;
      }    
    }
    
    return $ret;
}

sub traverse {
    my ($self, $coderef) = @_;
    # execute $coderef for each session id passing session id as the first and the only
    # argument
    
    my %seen;
    # make closure over the coderef and our seen hash, this will make sure that
    # we visit each session exactly once.
    my $visitor = sub {
      my ($sid) = @_;
      
      return if $seen{$sid}++;
      
      $coderef->($sid);
    };
    
    foreach my $driver (@{$self->{drivers}}) {
      $driver->traverse($visitor);
    }
}


sub _drivers {
  return @{shift->{drivers}};
}


sub errstr {
  my ($self) = @_;
  
  return join("\n",  map { "[ $_ ]" } grep { length } map { $_->errstr } @{$self->{drivers}});
}

        

=head1 COPYRIGHT

Copyright (C) 2009 Liquidweb Inc.

=head1 AUTHOR 

Chris Reinhardt <creinhardt@liquidweb.com>

=head1 SEE ALSO

L<CGI::Session::Driver>, L<CGI::Session>

=cut

1;