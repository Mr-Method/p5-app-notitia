package App::Notitia::Model::Endorsement;

use App::Notitia::Attributes;   # Will do namespace cleaning
use App::Notitia::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use App::Notitia::Util      qw( bind bind_fields check_field_js
                                delete_button field_options loc management_link
                                operation_links register_action_paths
                                save_button to_dt to_msg uri_for_action );
use Class::Null;
use Class::Usul::Functions  qw( is_member throw );
use Class::Usul::Time       qw( time2str );
use Try::Tiny;
use Unexpected::Functions   qw( ValidationErrors );
use Moo;

extends q(App::Notitia::Model);
with    q(App::Notitia::Role::PageConfiguration);
with    q(App::Notitia::Role::WebAuthorisation);
with    q(App::Notitia::Role::Navigation);
with    q(Class::Usul::TraitFor::ConnectInfo);
with    q(App::Notitia::Role::Schema);

# Public attributes
has '+moniker' => default => 'blots';

register_action_paths
   'blots/endorsement'  => 'endorsement',
   'blots/endorsements' => 'endorsements';

# Construction
around 'get_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash = $orig->( $self, $req, @args );

   $stash->{nav }->{list    } = $self->admin_navigation_links( $req );
   $stash->{page}->{location} = 'admin';

   return $stash;
};

# Private functions
my $_add_endorsement_links = sub {
   my ($req, $action, $name) = @_;

   return operation_links [ {
      class => 'fade',
      hint  => loc( $req, 'Hint' ),
      href  => uri_for_action( $req, $action, [ $name ] ),
      name  => 'add_blot',
      tip   => loc( $req, 'add_blot_tip', [ 'endorsement', $name ] ),
      type  => 'link',
      value => loc( $req, 'add_blot' ) } ];
};

my $_endorsements_headers = sub {
   my $req = shift;

   return [ map { { value => loc( $req, "blots_heading_${_}" ) } } 0 .. 1 ];
};

# Private methods
my $_add_endorsement_js = sub {
   my $self = shift;
   my $opts = { domain => 'schedule', form => 'Endorsement' };

   return [ check_field_js( 'type_code', $opts ),
            check_field_js( 'endorsed',  $opts ), ];
};

my $_bind_endorsement_fields = sub {
   my ($self, $blot) = @_;

   my $map      =  {
      type_code => { class => 'standard-field server' },
      endorsed  => { class => 'standard-field server' },
      notes     => { class => 'standard-field autosize' },
      points    => {},
   };

   return bind_fields $self->schema, $blot, $map, 'Endorsement';
};

my $_endorsement_links = sub {
   my ($self, $req, $name, $uri) = @_;

   my $opts = { args => [ $name, $uri ] }; my $links = [];

   for my $actionp (map { $self->moniker."/${_}" } 'endorsement' ) {
      push @{ $links }, {
         value => management_link( $req, $actionp, $name, $opts ) };
   }

   return @{ $links };
};

my $_find_endorsement_by = sub {
   my ($self, @args) = @_; my $schema = $self->schema;

   return $schema->resultset( 'Endorsement' )->find_endorsement_by( @args );
};

my $_maybe_find_endorsement = sub {
   return $_[ 2 ] ? $_[ 0 ]->$_find_endorsement_by( $_[ 1 ], $_[ 2 ] )
                  : Class::Null->new;
};

my $_update_endorsement_from_request = sub {
   my ($self, $req, $blot) = @_;

   my $params = $req->body_params; my $opts = { optional => TRUE };

   for my $attr (qw( type_code endorsed notes points )) {
      if (is_member $attr, [ 'notes' ]) { $opts->{raw} = TRUE }
      else { delete $opts->{raw} }

      my $v = $params->( $attr, $opts );

      defined $v or next; $v =~ s{ \r\n }{\n}gmx; $v =~ s{ \r }{\n}gmx;

      length $v and is_member $attr, [ qw( endorsed ) ] and $v = to_dt $v;

      $blot->$attr( $v );
   }

   return;
};

# Public methods
sub create_endorsement_action : Role(person_manager) {
   my ($self, $req) = @_;

   my $name    = $req->uri_params->( 0 );
   my $blot_rs = $self->schema->resultset( 'Endorsement' );
   my $blot    = $blot_rs->new_result( { recipient => $name } );

   $self->$_update_endorsement_from_request( $req, $blot );

   try   { $blot->insert }
   catch {
      $self->rethrow_exception
         ( $_, 'create', 'endorsement', $blot->label( $req ) );
   };

   my $action   = $self->moniker.'/endorsements';
   my $location = uri_for_action $req, $action, [ $name ];
   my $message  = [ to_msg 'Endorsement [_1] for [_2] added by [_3]',
                    $blot->type_code, $name, $req->session->user_label ];

   return { redirect => { location => $location, message => $message } };
}

sub delete_endorsement_action : Role(person_manager) {
   my ($self, $req) = @_;

   my $name     = $req->uri_params->( 0 );
   my $uri      = $req->uri_params->( 1 );
   my $blot     = $self->$_find_endorsement_by( $name, $uri ); $blot->delete;
   my $action   = $self->moniker.'/endorsements';
   my $location = uri_for_action $req, $action, [ $name ];
   my $message  = [ to_msg 'Endorsement [_1] for [_2] deleted by [_3]',
                    $uri, $name, $req->session->user_label ];

   return { redirect => { location => $location, message => $message } };
}

sub endorsement : Role(person_manager) {
   my ($self, $req) = @_;

   my $name       =  $req->uri_params->( 0 );
   my $uri        =  $req->uri_params->( 1, { optional => TRUE } );
   my $blot       =  $self->$_maybe_find_endorsement( $name, $uri );
   my $page       =  {
      fields      => $self->$_bind_endorsement_fields( $blot ),
      first_field => $uri ? 'endorsed' : 'type_code',
      literal_js  => $self->$_add_endorsement_js(),
      template    => [ 'contents', 'endorsement' ],
      title       => loc( $req, $uri ? 'endorsement_edit_heading'
                                     : 'endorsement_create_heading' ), };
   my $person_rs  =  $self->schema->resultset( 'Person' );
   my $person     =  $person_rs->find_by_shortcode( $name );
   my $args       =  $uri ? [ $name, $uri ] : [ $name ];
   my $fields     =  $page->{fields};

   if ($uri) {
      $fields->{type_code}->{disabled} = TRUE;
      $fields->{delete} = delete_button $req, $uri, { type => 'endorsement' };
   }
   else {
      my $opts = field_options $self->schema, 'Endorsement', 'endorsed',
                               { class => 'standard-field' };

      $fields->{endorsed} = bind 'endorsed', time2str( '%d/%m/%Y' ), $opts;
   }

   $fields->{username} = bind 'username', $person->label, { disabled => TRUE };
   $fields->{save} = save_button $req, $uri, { type => 'endorsement' };
   $fields->{href} = uri_for_action $req, 'blots/endorsement', $args;

   return $self->get_stash( $req, $page );
}

sub endorsements : Role(person_manager) {
   my ($self, $req) = @_;

   my $scode   =  $req->uri_params->( 0 );
   my $schema  =  $self->schema;
   my $person  =  $schema->resultset( 'Person' )->find_by_shortcode( $scode );
   my $page    =  {
      fields   => {
         blots => { headers  => $_endorsements_headers->( $req ),
                    rows     => [], },
         name  => { disabled => TRUE, label => loc( $req, 'Username' ),
                    name => 'username', value => $person->label }, },
      template => [ 'contents', 'endorsements' ],
      title    => loc( $req, 'endorsements_management_heading' ), };
   my $blot_rs =  $self->schema->resultset( 'Endorsement' );
   my $actionp =  $self->moniker.'/endorsement';
   my $fields  =  $page->{fields};
   my $rows    =  $fields->{blots}->{rows};

   $fields->{links} = $_add_endorsement_links->( $req, $actionp, $scode );

   for my $blot ($blot_rs->search_for_endorsements( $scode )->all) {
      push @{ $rows },
         [ { value => $blot->label( $req ) },
           $self->$_endorsement_links( $req, $scode, $blot->uri ) ];
   }

   return $self->get_stash( $req, $page );
}

sub update_endorsement_action : Role(person_manager) {
   my ($self, $req) = @_;

   my $name = $req->uri_params->( 0 );
   my $uri  = $req->uri_params->( 1 );
   my $blot = $self->$_find_endorsement_by( $name, $uri );

   $self->$_update_endorsement_from_request( $req, $blot ); $blot->update;

   my $message = [ to_msg 'Endorsement [_1] for [_2] updated by [_3]',
                   $uri, $name, $req->session->user_label ];

   return { redirect => { location => $req->uri, message => $message } };
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Notitia::Model::Endorsement - People and resource scheduling

=head1 Synopsis

   use App::Notitia::Model::Endorsement;
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

Copyright (c) 2016 Peter Flanigan. All rights reserved

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
