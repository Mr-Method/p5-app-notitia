package App::Notitia::Role::PageConfiguration;

use namespace::autoclean;

use App::Notitia::Constants qw( TRUE );
use App::Notitia::Util      qw( loc );
use Class::Usul::Functions  qw( throw );
use Try::Tiny;
use Web::ComposableRequest::Util qw( new_uri );
use Moo::Role;

requires qw( config initialise_stash load_page log );

# Construction
around 'execute' => sub {
   my ($orig, $self, $method, $req) = @_; my $conf = $self->config;

   my $session = $req->session; my $sess_version = $session->version;

   unless ($sess_version eq $conf->session_version) {
      $req->reset_session;
      throw 'Session version mismatch [_1] vs. [_2]. Reload page',
            [ $sess_version, $conf->session_version ];
   }

   my $stash = $orig->( $self, $method, $req );

   $req->authenticated and $self->activity_cache( $session->user_label );

   if (exists $stash->{redirect} and $req->authenticated and $req->referer) {
      unless ($stash->{redirect}->{location}) {
         my $location = new_uri $req->scheme, $req->referer;

         $location->query_form( {} );
         $stash->{redirect}->{location} = $location;
      }
   }

   my $key; $self->application->debug
      and $key = $self->config->appclass->env_var( 'trace' )
      and $self->application->dumper
         ( $key eq 'stash' ? $stash : $stash->{ $key } // {} );

   return $stash;
};

around 'initialise_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash  = $orig->( $self, $req, @args ); my $conf = $self->config;

   my $params = $req->query_params; my $sess = $req->session;

   for my $k (@{ $conf->stash_attr->{session} }) {
      try {
         my $v = $params->( $k, { optional => 1 } );

         $stash->{session}->{ $k } = defined $v ? $sess->$k( $v ) : $sess->$k();
      }
      catch { $self->log->warn( $_ ) };
   }

   $stash->{application_version} = $conf->appclass->VERSION;
   $stash->{template}->{skin} = $stash->{session}->{skin};

   my $links = $stash->{links} //= {};

   for my $k (@{ $conf->stash_attr->{links} }) {
      $links->{ $k } = $req->uri_for( $conf->$k().'/' );
   }

   $links->{cdnjs   } = $conf->cdnjs;
   $links->{base_uri} = $req->base;
   $links->{req_uri } = $req->uri;

   return $stash;
};

around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args ); my $conf = $self->config;

   for my $k (@{ $conf->stash_attr->{request} }) { $page->{ $k }   = $req->$k  }

   for my $k (@{ $conf->stash_attr->{config } }) { $page->{ $k } //= $conf->$k }

   my $skin = $req->session->skin || $conf->skin;

   $page->{template} //= [ "${skin}/menu" ];
   $page->{template}->[ 0 ] eq '/menu'
      and $page->{template}->[ 0 ] = "${skin}/menu";
   $page->{hint    } //= loc( $req, 'Hint' );
   $page->{wanted  } //=
      join '/', @{ $req->uri_params->( { optional => TRUE } ) // [] };

   return $page;
};

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Notitia::Role::PageConfiguration - People and resource scheduling

=head1 Synopsis

   use App::Notitia::Role::PageConfiguration;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Notitia.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2017 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
