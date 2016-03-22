package App::Notitia::Model::Vehicle;

use App::Notitia::Attributes;   # Will do namespace cleaning
use App::Notitia::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use App::Notitia::Util      qw( admin_navigation_links bind bind_fields button
                                check_field_server create_link
                                delete_button loc make_tip
                                management_link register_action_paths
                                save_button set_element_focus
                                slot_identifier uri_for_action );
use Class::Null;
use Class::Usul::Functions  qw( is_member throw );
use Class::Usul::Time       qw( str2date_time );
use HTTP::Status            qw( HTTP_EXPECTATION_FAILED );
use Moo;

extends q(App::Notitia::Model);
with    q(App::Notitia::Role::PageConfiguration);
with    q(App::Notitia::Role::WebAuthorisation);
with    q(Class::Usul::TraitFor::ConnectInfo);
with    q(App::Notitia::Role::Schema);

# Public attributes
has '+moniker' => default => 'asset';

register_action_paths
   'asset/assign'          => 'vehicle/assign',
   'asset/request_vehicle' => 'vehicle/request',
   'asset/unassign'        => 'vehicle/assign',
   'asset/vehicle'         => 'vehicle',
   'asset/vehicles'        => 'vehicles';

# Construction
around 'get_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash = $orig->( $self, $req, @args );

   $stash->{nav} = admin_navigation_links $req;
   $stash->{page}->{location} //= 'admin';

   return $stash;
};

# Private class attributes
my $_vehicle_links_cache = {};

# Private functions
my $_confirm_vehicle_button = sub {
   return button $_[ 0 ],
     { class => 'right-last', label => 'confirm', value => $_[ 1 ].'_vehicle' };
};

my $_quantity_list = sub {
   my ($type, $selected) = @_;

   my $opts   = { class => 'single-digit', label => NUL, type => 'select' };
   my $values = [ [ 0, 0 ], [ 1, 1 ], [ 2, 2 ], [ 3, 3 ], [ 4, 4 ] ];

   $values->[ $selected ]->[ 2 ] = { selected => TRUE };

   return { value => bind( "${type}_quantity", $values, $opts ) };
};

my $_vehicles_headers = sub {
   my $req = shift;

   return [ map { { value => loc( $req, "vehicles_heading_${_}" ) } } 0 .. 1 ];
};

my $_vehicle_request_button = sub {
   return button $_[ 0 ], { class => 'right-last' }, 'request', 'vehicle',
          [ $_[ 1 ] ];
};

my $_vehicle_request_headers = sub {
   my $req = shift;

   return [ map { { value => loc( $req, "vehicle_request_heading_${_}" ) } }
            0 .. 5 ];
};

my $_vehicle_title = sub {
   my ($req, $type, $private, $service) = @_;

   my $k = 'vehicles_management_heading';

   if    ($type and $private) { $k = 'vehicle_private_heading' }
   elsif ($type and $service) { $k = 'vehicle_service_heading' }
   elsif ($type)              { $k = "${type}_list_link" }

   return loc $req, $k;
};

my $_vehicle_type_tuple = sub {
   my ($type, $opts) = @_; $opts = { %{ $opts // {} } };

   $opts->{selected} //= NUL;
   $opts->{selected}   = $opts->{selected} eq $type ? TRUE : FALSE;

   return [ $type->name, $type, $opts ];
};

# Private methods
my $_add_vehicle_js = sub {
   my $self = shift; my $opts = { domain => 'schedule', form => 'Vehicle' };

   return [ check_field_server( 'vrn', $opts ) ];
};

my $_bind_request_fields = sub {
   my ($self, $req, $event, $opts) = @_; $opts //= {};

   my $map =  {
      name => { class => 'standard-field', disabled => TRUE,
                label => 'event_name' },
   };

   return bind_fields $self->schema, $event, $map, 'Event';
};

my $_bind_vehicle_fields = sub {
   my ($self, $req, $vehicle, $opts) = @_; $opts //= {};

   my $disabled =  $opts->{disabled} // FALSE;
   my $map      =  {
      aquired   => { disabled => $disabled },
      disposed  => { disabled => $disabled },
      name      => { disabled => $disabled,
                     label    => 'vehicle_name',
                     tip      => make_tip( $req, 'vehicle_name_field_tip') },
      notes     => { class    => 'standard-field autosize',
                     disabled => $disabled },
      vrn       => { class    => 'standard-field server',
                     disabled => $disabled },
   };

   return bind_fields $self->schema, $vehicle, $map, 'Vehicle';
};

my $_find_vreq_by = sub {
   my ($self, $event, $vehicle_type) = @_;

   my $rs = $self->schema->resultset( 'VehicleRequest' );

   return $rs->search( { event_id => $event->id,
                         type_id  => $vehicle_type->id } )->single;
};

my $_list_vehicle_types = sub {
   my ($self, $opts) = @_; $opts = { %{ $opts // {} } };

   my $fields  = delete $opts->{fields} // {};
   my $type_rs = $self->schema->resultset( 'Type' );

   return [ map { $_vehicle_type_tuple->( $_, $fields ) }
            $type_rs->list_vehicle_types( $opts )->all ];
};

my $_maybe_find_vehicle = sub {
   my ($self, $vrn) = @_; $vrn or return Class::Null->new;

   my $rs = $self->schema->resultset( 'Vehicle' );

   return $rs->find_vehicle_by( $vrn, { prefetch => [ 'type' ] } );
};

my $_maybe_find_vreq = sub {
   my ($self, $event, $vehicle_type) = @_;

   my $vreq = $self->$_find_vreq_by( $event, $vehicle_type );

   $vreq and return $vreq; my $rs = $self->schema->resultset( 'VehicleRequest');

   return $rs->new_result( { event_id => $event->id,
                             type_id  => $vehicle_type->id } );
};

my $_owner_list = sub {
   my ($self, $vehicle) = @_; my $schema = $self->schema;

   my $opts   = { fields => { selected => $vehicle->owner } };
   my $people = $schema->resultset( 'Person' )->list_all_people( $opts );

   return bind 'owner_id', [ [ NUL, NUL ], @{ $people } ], { numify => TRUE };
};

my $_req_quantity = sub {
   my ($self, $event, $vehicle_type) = @_;

   my $vreq = $self->$_find_vreq_by( $event, $vehicle_type );

   return $vreq ? $vreq->quantity : 0;
};

my $_toggle_assignment = sub {
   my ($self, $req, $action) = @_;

   my $method    = "${action}_slot";
   my $params    = $req->uri_params;
   my $rota_name = $params->( 0 );
   my $rota_date = $params->( 1 );
   my $slot_name = $params->( 2 );
   my $vrn       = $req->body_params->( 'vehicle' );
   my $schema    = $self->schema;
   my $vehicle   = $schema->resultset( 'Vehicle' )->find_vehicle_by( $vrn );

   my ($shift_type, $slot_type, $subslot) = split m{ _ }mx, $slot_name, 3;

   $vehicle->$method( $rota_name, $rota_date, $shift_type,
                      $slot_type, $subslot, $req->username );

   my $label     = slot_identifier
      ( $rota_name, $rota_date, $shift_type, $slot_type, $subslot );
   my $message   = [ "Vehicle [_1] ${action}ed to [_2] by [_3]",
                     $vrn, $label, $req->username ];
   my $location  = uri_for_action
      ( $req, 'sched/day_rota', [ $rota_name, $rota_date, $slot_name ] );

   return { redirect => { location => $location, message => $message } };
};

my $_update_vehicle_from_request = sub {
   my ($self, $req, $vehicle) = @_; my $params = $req->body_params; my $v;

   my $opts = { optional => TRUE };

   for my $attr (qw( aquired disposed name notes vrn )) {
      if (is_member $attr, [ 'notes' ]) { $opts->{raw} = TRUE }
      else { delete $opts->{raw} }

      my $v = $params->( $attr, $opts ); defined $v or next;

      $v =~ s{ \r\n }{\n}gmx; $v =~ s{ \r }{\n}gmx;

      length $v and is_member $attr, [ qw( aquired disposed ) ]
         and $v = str2date_time $v, 'GMT';

      $vehicle->$attr( $v );
   }

   $v = $params->( 'owner_id', $opts ); $vehicle->owner_id( $v ? $v : undef );
   $v = $params->( 'type', $opts ); defined $v and $vehicle->type_id( $v );

   return;
};

my $_update_vehicle_req_from_request = sub {
   my ($self, $req, $vreq, $vehicle_type) = @_;

   my $v = $req->body_params->( "${vehicle_type}_quantity" );

   defined $v and $vreq->quantity( $v );

   return;
};

my $_vehicle_links = sub {
   my ($self, $req, $vehicle) = @_; my $vrn = $vehicle->[ 1 ]->vrn;

   my $links = $_vehicle_links_cache->{ $vrn }; $links and return @{ $links };

   $links = [];

   for my $actionp (map { $self->moniker."/${_}" } 'vehicle') {
      push @{ $links }, { value => management_link( $req, $actionp, $vrn ) };
   }

   $_vehicle_links_cache->{ $vrn } = $links;

   return @{ $links };
};

my $_vehicle_type_list = sub {
   my ($self, $vehicle) = @_;

   my $opts   = { fields => { selected => $vehicle->type } };
   my $values = [ [ NUL, NUL ], @{ $self->$_list_vehicle_types( $opts ) } ];

   return bind 'type', $values, { label => 'vehicle_type', numify => TRUE };
};

# Public methods
sub assign : Role(rota_manager) {
   my ($self, $req) = @_;

   my $params = $req->uri_params;
   my $args   = [ $params->( 0 ), $params->( 1 ), $params->( 2 ) ];
   my $action = $req->query_params->( 'action' );
   my $stash  = $self->dialog_stash( $req, "${action}-vehicle" );
   my $page   = $stash->{page};
   my $fields = $page->{fields};

   if ($action eq 'assign') {
      my $where  = { service => TRUE, type => 'bike' };
      my $rs     = $self->schema->resultset( 'Vehicle' );
      my $values = [ [ NUL, NUL ], @{ $rs->list_vehicles( $where ) } ];

      $fields->{vehicle}
         = bind 'vehicle', $values, { class => 'right-last', label => NUL };
      $page->{literal_js} = set_element_focus 'assign-vehicle', 'vehicle';
   }
   else {
      my $vrn = $req->query_params->( 'vehicle' );

      $fields->{vehicle} = { name => 'vehicle', value => $vrn };
   }

   $fields->{href   } = uri_for_action $req, $self->moniker.'/vehicle', $args;
   $fields->{confirm} = $_confirm_vehicle_button->( $req, $action );
   $fields->{assign } = bind $action, $action, { class => 'right' };

   return $stash;
}

sub assign_vehicle_action : Role(rota_manager) {
   return $_[ 0 ]->$_toggle_assignment( $_[ 1 ], 'assign' );
}

sub create_vehicle_action : Role(rota_manager) {
   my ($self, $req) = @_;

   my $vehicle  = $self->schema->resultset( 'Vehicle' )->new_result( {} );

   $self->$_update_vehicle_from_request( $req, $vehicle ); $vehicle->insert;

   my $vrn      = $vehicle->vrn;
   my $message  = [ 'Vehicle [_1] created by [_2]', $vrn, $req->username ];
   my $location = uri_for_action $req, $self->moniker.'/vehicle', [ $vrn ];

   return { redirect => { location => $location, message => $message } };
}

sub delete_vehicle_action : Role(rota_manager) {
   my ($self, $req) = @_;

   my $vrn     = $req->uri_params->( 0 );
   my $vehicle = $self->schema->resultset( 'Vehicle' )->find_vehicle_by( $vrn );

   $vehicle->delete;

   my $message  = [ 'Vehicle [_1] deleted by [_2]', $vrn, $req->username ];
   my $location = uri_for_action $req, $self->moniker.'/vehicles';

   return { redirect => { location => $location, message => $message } };
}

sub request_vehicle : Role(rota_manager) Role(event_manager) {
   my ($self, $req) = @_;

   my $uri       =  $req->uri_params->( 0 );
   my $event     =  $self->schema->resultset( 'Event' )->find_event_by( $uri );
   my $page      =  {
      fields     => $self->$_bind_request_fields( $req, $event ),
      template   => [ 'contents', 'vehicle-request' ],
      title      => loc( $req, 'vehicle_request_heading' ), };
   my $type_rs   =  $self->schema->resultset( 'Type' );
   my $opts      =  { disabled => TRUE };
   my $fields    =  $page->{fields};

   $fields->{action  } = uri_for_action $req, 'asset/vehicle', [ $uri ];
   $fields->{date    } = bind 'event_date', $event->rota->date, $opts;
   $fields->{request } = $_vehicle_request_button->( $req, $event );
   $fields->{vehicles} = { headers => $_vehicle_request_headers->( $req ) };

   for my $vehicle_type ($type_rs->list_types( 'vehicle' )->all) {
      my $quant = $self->$_req_quantity( $event, $vehicle_type );
      my $row   = [ { value => loc( $req, $vehicle_type ) },
                      $_quantity_list->( $vehicle_type, $quant ) ];

      if ($quant) {
         for my $vehicle (0 .. $quant - 1) {
            push @{ $row }, { value => 'req' };
         }
      }

      push @{ $fields->{vehicles}->{rows} }, $row;
   }

   return $self->get_stash( $req, $page );
}

sub request_vehicle_action : Role(event_manager) {
   my ($self, $req) = @_;

   my $uri     = $req->uri_params->( 0 );
   my $event   = $self->schema->resultset( 'Event' )->find_event_by( $uri );
   my $type_rs = $self->schema->resultset( 'Type' );

   for my $vehicle_type ($type_rs->list_types( 'vehicle' )->all) {
      my $vreq = $self->$_maybe_find_vreq( $event, $vehicle_type );

      $self->$_update_vehicle_req_from_request( $req, $vreq, $vehicle_type );

      if ($vreq->in_storage) { $vreq->update } else { $vreq->insert }
   }

   my $actionp  = $self->moniker.'/request_vehicle';
   my $location = uri_for_action $req, $actionp, [ $uri ];
   my $message  = [ 'Vehicle request for event [_1] updated by [_2]',
                    $event, $req->username ];

   return { redirect => { location => $location, message => $message } };
}

sub unassign_vehicle_action : Role(rota_manager) {
   return $_[ 0 ]->$_toggle_assignment( $_[ 1 ], 'unassign' );
}

sub update_vehicle_action : Role(rota_manager) {
   my ($self, $req) = @_;

   my $vrn     = $req->uri_params->( 0 );
   my $vehicle = $self->schema->resultset( 'Vehicle' )->find_vehicle_by( $vrn );

   $self->$_update_vehicle_from_request( $req, $vehicle ); $vehicle->update;

   my $message = [ 'Vehicle [_1] updated by [_2]', $vrn, $req->username ];

   return { redirect => { location => $req->uri, message => $message } };
}

sub vehicle : Role(rota_manager) {
   my ($self, $req) = @_;

   my $action    =  $self->moniker.'/vehicle';
   my $vrn       =  $req->uri_params->( 0, { optional => TRUE } );
   my $vehicle   =  $self->$_maybe_find_vehicle( $vrn );
   my $page      =  {
      fields     => $self->$_bind_vehicle_fields( $req, $vehicle ),
      literal_js => $self->$_add_vehicle_js(),
      template   => [ 'contents', 'vehicle' ],
      title      => loc( $req, $vrn ? 'vehicle_edit_heading'
                                    : 'vehicle_create_heading' ), };
   my $fields    =  $page->{fields};

   if ($vrn) {
      $fields->{delete} = delete_button $req, $vrn, 'vehicle';
      $fields->{href  } = uri_for_action $req, $action, [ $vrn ];
   }

   $fields->{owner} = $self->$_owner_list( $vehicle );
   $fields->{type } = $self->$_vehicle_type_list( $vehicle );
   $fields->{save } = save_button $req, $vrn, 'vehicle';

   return $self->get_stash( $req, $page );
}

sub vehicles : Role(rota_manager) {
   my ($self, $req) = @_;

   my $params    =  $req->query_params;
   my $type      =  $params->( 'type',    { optional => TRUE } );
   my $private   =  $params->( 'private', { optional => TRUE } ) || FALSE;
   my $service   =  $params->( 'service', { optional => TRUE } ) || FALSE;
   my $action    =  $self->moniker.'/vehicle';
   my $page      =  {
      fields     => {
         add     => create_link( $req, $action, 'vehicle' ),
         headers => $_vehicles_headers->( $req ),
         rows    => [], },
      template   => [ 'contents', 'table' ],
      title      => $_vehicle_title->( $req, $type, $private, $service ), };
   my $where     =  { private => $private, service => $service, type => $type };
   my $rs        =  $self->schema->resultset( 'Vehicle' );
   my $vehicles  =  $rs->list_vehicles( $where );
   my $rows      =  $page->{fields}->{rows};

   for my $vehicle (@{ $vehicles }) {
      push @{ $rows }, [ { value => $vehicle->[ 0 ] },
                         $self->$_vehicle_links( $req, $vehicle ) ];
   }

   return $self->get_stash( $req, $page );
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Notitia::Model::Vehicle - People and resource scheduling

=head1 Synopsis

   use App::Notitia::Model::Vehicle;
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
