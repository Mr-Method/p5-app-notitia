package App::Notitia::Model::Endorsement;

use App::Notitia::Attributes;   # Will do namespace cleaning
use App::Notitia::Constants qw( EXCEPTION_CLASS FALSE NUL PIPE_SEP SPC TRUE );
use App::Notitia::DOM       qw( new_container p_action p_cell p_item p_js p_link
                                p_list p_fields p_row p_table p_textfield );
use App::Notitia::Util      qw( check_field_js link_options loc local_dt locd
                                locm now_dt register_action_paths
                                to_dt to_msg );
use Class::Null;
use Class::Usul::Functions  qw( is_member throw );
use Try::Tiny;
use Unexpected::Functions   qw( ValidationErrors );
use Moo;

extends q(App::Notitia::Model);
with    q(App::Notitia::Role::PageConfiguration);
with    q(App::Notitia::Role::WebAuthorisation);
with    q(App::Notitia::Role::Navigation);

# Public attributes
has '+moniker' => default => 'blots';

register_action_paths
   'blots/endorsement'  => 'endorsement',
   'blots/endorsements' => 'endorsements';

# Construction
around 'get_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash = $orig->( $self, $req, @args );

   $stash->{page}->{location} = 'management';
   $stash->{navigation}
      = $self->management_navigation_links( $req, $stash->{page} );

   return $stash;
};

# Private functions
my $_bind_endorsement_fields = sub {
   my ($blot, $opts) = @_; $opts //= {};

   my $disabled = $opts->{action} eq 'update' ? TRUE : FALSE;

   return
   [  type_code => { class => 'standard-field server', disabled => $disabled },
      endorsed  => { class => 'standard-field server', type => 'date',
                     value => local_dt( $disabled ? $blot->endorsed : now_dt )},
      points    => {},
      notes     => { class => 'standard-field autosize', type => 'textarea' },
      ];
};

my $_endorsement_js = sub {
   my $opts = { domain => 'schedule', form => 'Endorsement' };

   return check_field_js( 'type_code', $opts ),
          check_field_js( 'endorsed',  $opts );
};

my $_endorsements_headers = sub {
   my $req = shift;

   return [ map { { value => loc( $req, "blots_heading_${_}" ) } } 0 .. 1 ];
};

# Private methods
my $_endorsement_links = sub {
   my ($self, $req, $scode, $blot) = @_; my $row = [];

   my $actionp = $self->moniker.'/endorsement';
   my $args    = [ $scode, $blot->uri ];
   my $params  = $req->query_params->( {
      optional => TRUE } ); delete $params->{mid};
   my $href    = $req->uri_for_action( $actionp, $args, $params );
   my $cell    = p_cell $row, {};

   p_link $cell, 'endorsement', $href, {
      action  => 'update',
      args    => [ $blot->recipient->label ],
      request => $req,
      value   => $blot->label( $req ) };

   p_item $row, locd $req, $blot->endorsed;

   return $row;
};

my $_endorsement_ops_links = sub {
   my ($self, $req, $person) = @_; my $links = [];

   my $actionp = $self->moniker.'/endorsements';
   my $args    = [ $person->shortcode ];
   my $params  = $req->query_params->( {
      optional => TRUE } ); delete $params->{mid};
   my $href    = $req->uri_for_action( $actionp, $args, $params );

   p_link $links, 'endorsements', $href, {
      action => 'list', args => [ $person->label ], request => $req };

   return $links;
};

my $_endorsements_ops_links = sub {
   my ($self, $req, $person) = @_; my $links = [];

   my $actionp = $self->moniker.'/endorsement';
   my $args    = [ $person->shortcode ];
   my $params  = $req->query_params->( {
      optional => TRUE } ); delete $params->{mid};
   my $href    = $req->uri_for_action( $actionp, $args, $params );

   p_link $links, 'endorsement', $href, {
      action => 'add', args => [ $person->label ], request => $req };

   return $links;
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

   my $scode   = $req->uri_params->( 0 );
   my $blot_rs = $self->schema->resultset( 'Endorsement' );
   my $blot    = $blot_rs->new_result( { recipient => $scode } );

   $self->$_update_endorsement_from_request( $req, $blot );

   my $label   = $blot->label( $req );

   try   { $blot->insert }
   catch { $self->blow_smoke( $_, 'create', 'endorsement', $label ) };

   my $uri      = $blot->uri;
   my $type     = $blot->type_code;
   my $message  = "action:create-endorsement endorsement_uri:${uri} "
                . "shortcode:${scode} endorsement_type:${type}";

   $self->send_event( $req, $message );

   my $action   = $self->moniker.'/endorsements';
   my $location = $req->uri_for_action( $action, [ $scode ] );
   my $key      = 'Endorsement [_1] for [_2] added by [_3]';

   $message = [ to_msg $key, $type, $scode, $req->session->user_label ];

   return { redirect => { location => $location, message => $message } };
}

sub delete_endorsement_action : Role(person_manager) {
   my ($self, $req) = @_;

   my $scode    = $req->uri_params->( 0 );
   my $uri      = $req->uri_params->( 1 );
   my $blot     = $self->$_find_endorsement_by( $scode, $uri ); $blot->delete;
   my $message  = "action:delete-endorsement endorsement_uri:${uri} "
                . "shortcode:${scode} endorsement_type:".$blot->type_code;

   $self->send_event( $req, $message );

   my $actionp  = $self->moniker.'/endorsements';
   my $location = $req->uri_for_action( $actionp, [ $scode ] );
   my $key      = 'Endorsement [_1] for [_2] deleted by [_3]';

   $message = [ to_msg $key, $uri, $scode, $req->session->user_label ];

   return { redirect => { location => $location, message => $message } };
}

sub endorsement : Role(person_manager) {
   my ($self, $req) = @_;

   my $actionp    =  $self->moniker.'/endorsement';
   my $scode      =  $req->uri_params->( 0 );
   my $uri        =  $req->uri_params->( 1, { optional => TRUE } );
   my $role       =  $req->query_params->( 'role', { optional => TRUE } );
   my $action     =  $uri ? 'update' : 'create';
   my $href       =  $req->uri_for_action( $actionp, [ $scode, $uri ] );
   my $form       =  new_container 'endorsement-admin', $href;
   my $page       =  {
      first_field => $uri ? 'points' : 'type_code',
      forms       => [ $form ],
      selected    => $role ? "${role}_list" : 'people_list',
      title       => loc $req, "endorsement_${action}_heading" };
   my $blot       =  $self->$_maybe_find_endorsement( $scode, $uri );
   my $person_rs  =  $self->schema->resultset( 'Person' );
   my $person     =  $person_rs->find_by_shortcode( $scode );
   my $args       =  [ 'endorsement', $person->label ];
   my $links      =  $self->$_endorsement_ops_links( $req, $person );

   p_js $page, $_endorsement_js->(),

   p_list $form, PIPE_SEP, $links, link_options 'right';

   p_textfield $form, 'username', $person->label, { disabled => TRUE };

   p_fields $form, $self->schema, 'Endorsement', $blot,
      $_bind_endorsement_fields->( $blot, { action => $action } );

   p_action $form, $action, $args, { request => $req };

   $uri and p_action $form, 'delete', $args, { request => $req };

   return $self->get_stash( $req, $page );
}

sub endorsements : Role(person_manager) {
   my ($self, $req) = @_;

   my $scode   =  $req->uri_params->( 0 );
   my $role    =  $req->query_params->( 'role', { optional => TRUE } );
   my $form    =  new_container;
   my $page    =  {
      forms    => [ $form ],
      selected => $role ? "${role}_list" : 'people_list',
      title    => loc $req, 'endorsements_management_heading' };
   my $schema  =  $self->schema;
   my $person  =  $schema->resultset( 'Person' )->find_by_shortcode( $scode );
   my $blot_rs =  $schema->resultset( 'Endorsement' );
   my $links   =  $self->$_endorsements_ops_links( $req, $person );

   p_textfield $form, 'username', $person->label, { disabled => TRUE };

   p_list $form, PIPE_SEP, $links, link_options 'right';

   my $table = p_table $form, { headers => $_endorsements_headers->( $req ) };

   p_row $table, [ map { $self->$_endorsement_links( $req, $scode, $_ ) }
                   $blot_rs->search_for_endorsements( $scode )->all ];

   return $self->get_stash( $req, $page );
}

sub update_endorsement_action : Role(person_manager) {
   my ($self, $req) = @_;

   my $scode = $req->uri_params->( 0 );
   my $uri   = $req->uri_params->( 1 );
   my $blot  = $self->$_find_endorsement_by( $scode, $uri );

   $self->$_update_endorsement_from_request( $req, $blot );
   $blot->update;

   my $message = "action:update-endorsement endorsement_uri:${uri} "
               . "shortcode:${scode} endorsement_type:".$blot->type_code;

   $self->send_event( $req, $message );

   my $actionp  = $self->moniker.'/endorsements';
   my $location = $req->uri_for_action( $actionp, [ $scode ] );
   my $key      = 'Endorsement [_1] for [_2] updated by [_3]';

   $message = [ to_msg $key, $uri, $scode, $req->session->user_label ];

   return { redirect => { location => $location, message => $message } };
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
