package App::Notitia::Model::Vehicle;

use App::Notitia::Attributes;   # Will do namespace cleaning
use App::Notitia::Constants qw( BATCH_MODE EXCEPTION_CLASS
                                FALSE NUL PIPE_SEP SPC TRUE );
use App::Notitia::DOM       qw( new_container p_action p_button p_date p_fields
                                p_hidden p_item p_js p_link p_list p_row
                                p_select p_table p_tag p_textarea p_textfield );
use App::Notitia::Util      qw( assign_link check_field_js dialog_anchor
                                display_duration link_options loc local_dt locd
                                locm make_tip management_link month_label
                                now_dt page_link_set register_action_paths
                                set_element_focus slot_identifier time2int
                                to_dt to_msg );
use Class::Null;
use Class::Usul::Functions  qw( is_member throw );
use Try::Tiny;
use Moo;

extends q(App::Notitia::Model);
with    q(App::Notitia::Role::PageConfiguration);
with    q(App::Notitia::Role::WebAuthorisation);
with    q(App::Notitia::Role::Navigation);

# Public attributes
has '+moniker' => default => 'asset';

register_action_paths
   'asset/adhoc_vehicle'   => 'adhoc-vehicle',
   'asset/assign'          => 'vehicle-assign',
   'asset/history_list'    => 'vehicle-histories',
   'asset/history_view'    => 'vehicle-history',
   'asset/request_info'    => 'vehicle-request-info',
   'asset/request_vehicle' => 'vehicle-request',
   'asset/unassign'        => 'vehicle-assign',
   'asset/vehicle'         => 'vehicle',
   'asset/vehicle_events'  => 'vehicle-events',
   'asset/vehicle_model'   => 'vehicle-model',
   'asset/vehicles'        => 'vehicles';

# Construction
around 'get_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash = $orig->( $self, $req, @args );

   $stash->{page}->{location} //= 'management';
   $stash->{navigation}
      = $self->management_navigation_links( $req, $stash->{page} );

   return $stash;
};

my @HISTORY_ATTR = qw( current_miles front_tyre_life front_tyre_miles
                       insurance_due last_fueled mot_due next_service_due
                       next_service_miles rear_tyre_life
                       rear_tyre_miles tax_due );

# Private functions
my $_compare_forward = sub {
   my ($x, $y) = @_;

   $x->[ 0 ]->start_date < $y->[ 0 ]->start_date and return -1;
   $x->[ 0 ]->start_date > $y->[ 0 ]->start_date and return  1;

   $x = time2int $x->[ 1 ]->[ 2 ]->{value};
   $y = time2int $y->[ 1 ]->[ 2 ]->{value};

   $x < $y and return -1; $x > $y and return 1; return 0;
};

my $_compare_reverse = sub { # Duplication for efficiency
   my ($y, $x) = @_;

   $x->[ 0 ]->start_date < $y->[ 0 ]->start_date and return -1;
   $x->[ 0 ]->start_date > $y->[ 0 ]->start_date and return  1;

   $x = time2int $x->[ 1 ]->[ 2 ]->{value};
   $y = time2int $y->[ 1 ]->[ 2 ]->{value};

   $x < $y and return -1; $x > $y and return 1; return 0;
};

my $_create_action = sub {
   return { action => 'create', container_class => 'add-link',
            request => $_[ 0 ] };
};

my $_find_vreq_by = sub {
   my ($schema, $event, $vehicle_type) = @_;

   my $rs = $schema->resultset( 'VehicleRequest' );

   return $rs->search( { event_id => $event->id,
                         type_id  => $vehicle_type->id } )->single;
};

my $_history_list_headers = sub {
   my $req = shift; my $header = 'vehicle_history_heading';

   return [ map { { value => locm $req, "${header}_${_}" } } 0 .. 1 ];
};

my $_maybe_find_vehicle = sub {
   my ($schema, $vrn) = @_; $vrn or return Class::Null->new;

   my $rs = $schema->resultset( 'Vehicle' );

   return $rs->find_vehicle_by( $vrn, { prefetch => [ 'type' ] } );
};

my $_owner_list = sub {
   my ($schema, $vehicle, $disabled) = @_;

   my $opts   = { fields => { selected => $vehicle->owner } };
   my $people = $schema->resultset( 'Person' )->list_all_people( $opts );

   $opts = { name  => 'owner_id', numify => TRUE,
             type  => 'select',   value  => [ [ NUL, NUL ], @{ $people } ] };
   $disabled and $opts->{disabled} = TRUE;

   return $opts;
};

my $_quantity_list = sub {
   my ($page, $type, $selected) = @_;

   my $select = { class => 'single-digit-select narrow', };
   my $opts   = {
      class => 'single-digit', disabled => $page->{disabled}, label => NUL };
   my $values = [ [ 0, 0 ], [ 1, 1 ], [ 2, 2 ], [ 3, 3 ], [ 4, 4 ], ];

   $values->[ $selected ]->[ 2 ] = { selected => TRUE };

   p_select $select , "${type}_quantity", $values, $opts;

   return $select;
};

my $_query_params_no_mid = sub {
   my $req = shift; my $params = $req->query_params->( { optional => TRUE } );

   delete $params->{mid};
   return $params;
};

my $_transport_links = sub {
   my ($self, $req, $event) = @_; my @links;

   my $actionp = $self->moniker.'/request_vehicle';
   my $args    = { args => [ $event->uri ] };

   p_item \@links, management_link $req, $actionp, 'edit', $args;

   return @links;
};

my $_update_vehicle_req_from_request = sub {
   my ($req, $vreq, $vehicle_type) = @_;

   my $v = $req->body_params->( "${vehicle_type}_quantity" );

   defined $v and $vreq->quantity( $v );

   return;
};

my $_vehicle_events_headers = sub {
   return [ map { { value => loc( $_[ 0 ], "vehicle_events_heading_${_}" ) } }
            0 .. 4 ];
};

my $_vehicle_event_links = sub {
   my ($self, $req, $event) = @_; my @links;

   my $args = { args => [ $event->vehicle->vrn, $event->uri ] };

   p_item \@links, management_link $req, 'event/vehicle_event', 'edit', $args;

   return @links;
};

my $_vehicle_js = sub {
   my $vrn  = shift;
   my $opts = { domain => $vrn ? 'update' : 'insert', form => 'Vehicle' };

   return check_field_js 'vrn', $opts;
};

my $_vehicle_slot_links = sub {
   my ($self, $req, $slot) = @_; my @links;

   my $args = { args => [ $slot->rota_type, local_dt( $slot->date )->ymd ] };

   p_item \@links, management_link $req, 'day/day_rota', 'edit', $args;

   return @links;
};

my $_vehicle_request_headers = sub {
   my $req = shift;

   return [ map { { value => loc( $req, "vehicle_request_heading_${_}" ) } }
            0 .. 5 ];
};

my $_vehicle_title = sub {
   my ($req, $params) = @_;

   my $k = 'vehicles_management_heading';

   if    ($params->{adhoc  }) { $k = 'adhoc_vehicles_heading' }
   elsif ($params->{private}) { $k = 'vehicle_private_heading' }
   elsif ($params->{service}) { $k = 'vehicle_service_heading' }
   elsif ($params->{type   }) { $k = $params->{type}.'_list_link' }

   return loc $req, $k;
};

my $_vehicle_model_tuple = sub {
   my ($model, $opts) = @_; $opts = { %{ $opts // {} } };

   $opts->{selected} //= NUL;
   $opts->{selected}   = $opts->{selected} eq $model ? TRUE : FALSE;

   return [ $model->label, $model, $opts ];
};

my $_vehicle_type_tuple = sub {
   my ($type, $opts) = @_; $opts = { %{ $opts // {} } };

   $opts->{selected} //= NUL;
   $opts->{selected}   = $opts->{selected} eq $type ? TRUE : FALSE;

   return [ $type->name, $type, $opts ];
};

my $_vehicles_headers = sub {
   my ($req, $params) = @_; my $max = $params->{service} ? 5 : 2;

   return [ map { { value => loc( $req, "vehicles_heading_${_}" ) } }
            0 .. $max ];
};

my $_find_or_create_vreq = sub {
   my ($schema, $event, $vehicle_type) = @_;

   my $vreq = $_find_vreq_by->( $schema, $event, $vehicle_type );

   $vreq and return $vreq; my $rs = $schema->resultset( 'VehicleRequest' );

   return $rs->new_result( { event_id => $event->id,
                             type_id  => $vehicle_type->id } );
};

my $_list_vehicle_models = sub {
   my ($schema, $opts) = @_; $opts = { %{ $opts // {} } };

   my $fields  = delete $opts->{fields} // {};
   my $type_rs = $schema->resultset( 'Type' );

   return [ map { $_vehicle_model_tuple->( $_, $fields ) }
            $type_rs->search_for_vehicle_models( $opts )->all ];
};

my $_list_vehicle_types = sub {
   my ($schema, $opts) = @_; $opts = { %{ $opts // {} } };

   my $fields  = delete $opts->{fields} // {};
   my $type_rs = $schema->resultset( 'Type' );

   return [ map { $_vehicle_type_tuple->( $_, $fields ) }
            $type_rs->search_for_vehicle_types( $opts )->all ];
};

my $_req_quantity = sub {
   my ($schema, $event, $vehicle_type) = @_;

   my $vreq = $_find_vreq_by->( $schema, $event, $vehicle_type );

   return $vreq ? $vreq->quantity : 0;
};

my $_select_nav_link_name = sub {
   my $params = shift;

   return $params->{adhoc  } ? 'adhoc_vehicles'
        : $params->{private} ? 'private_vehicles'
        : $params->{service} ? 'service_vehicles'
                             : 'vehicles_list';
};

my $_vehicle_model_list = sub {
   my ($schema, $vehicle, $disabled) = @_;

   my $opts   = { fields => { selected => $vehicle->model } };
   my $values = [ [ NUL, undef], @{ $_list_vehicle_models->( $schema, $opts )}];

   return {
      class    => 'standard-field',
      disabled => $disabled,
      label    => 'vehicle_model',
      name     => 'model',
      numify   => TRUE,
      type     => 'select',
      value    => $values,
   };
};

my $_vehicle_type_list = sub {
   my ($schema, $vehicle, $disabled) = @_;

   my $opts   = { fields => { selected => $vehicle->type } };
   my $values = [ [ NUL, undef ], @{ $_list_vehicle_types->( $schema, $opts )}];

   $opts = { class => 'standard-field required', label  => 'vehicle_type',
             name  => 'type',                    numify => TRUE,
             type  => 'select',                  value  => $values };
   $disabled and $opts->{disabled} = TRUE;

   return $opts;
};

my $_vreq_row = sub {
   my ($schema, $req, $page, $event, $vehicle_type) = @_;

   my $uri    = $page->{event_uri};
   my $rs     = $schema->resultset( 'Transport' );
   my $tports = $rs->search_for_vehicle_by_type( $event->id, $vehicle_type->id);
   my $quant  = $_req_quantity->( $schema, $event, $vehicle_type );
   my $is_manager = is_member 'rota_manager', $req->session->roles;
   my $row    = [ { value => loc( $req, $vehicle_type ) },
                  $_quantity_list->( $page, $vehicle_type, $quant ) ];

   $quant or return $row;

   for my $slotno (0 .. $quant - 1) {
      my $opts       = {
         is_manager  => $is_manager,
         name        => "${vehicle_type}_event_${slotno}",
         operator    => $event->owner,
         transport   => $tports->next,
         type        => $vehicle_type,
         vehicle_req => TRUE, };

      push @{ $row }, assign_link $req, $page, [ $uri ], $opts;
   }

   return $row;
};

# Private methods
my $_bind_history_fields = sub {
   my ($self, $req, $history, $params) = @_;

   $history->id or return
      [ period_start => { class => 'standard-field', type => 'month' } ];

   return
      [ period_start       => {
         class => 'standard-field', disabled => TRUE, type => 'month' },
        current_miles      => { class => 'standard-field' },
        last_fueled        => { type => 'date' },
        next_service_due   => { type => 'date' },
        next_service_miles => {},
        tax_due            => { type => 'date' },
        mot_due            => { type => 'date' },
        insurance_due      => { type => 'date' },
        front_tyre_miles   => {},
        front_tyre_life    => {},
        rear_tyre_miles    => {},
        rear_tyre_life     => {},
        ];
};

my $_bind_vehicle_fields = sub {
   my ($self, $req, $vehicle, $opts) = @_; $opts //= {};

   my $disabled = $opts->{disabled} // FALSE; my $schema = $self->schema;

   return
   [  vrn         => { class    => 'standard-field server',
                       disabled => $disabled },
      type        => $_vehicle_type_list->( $schema, $vehicle, $disabled ),
      model       => $_vehicle_model_list->( $schema, $vehicle, $disabled ),
      name        => !$opts->{adhoc} && !$opts->{private} ? {
         disabled => $disabled,
         label    => 'vehicle_name',
         tip      => make_tip $req, 'vehicle_name_field_tip' } : FALSE,
      owner       => !$opts->{adhoc} && !$opts->{service} ?
         $_owner_list->( $schema, $vehicle, $disabled ) : FALSE,
      colour      => { disabled => $disabled,
                       tip      => make_tip $req, 'vehicle_colour_field_tip' },
      aquired     => { disabled => $disabled, type => 'date' },
      disposed    => { class    => 'standard-field clearable',
                       disabled => $disabled, type => 'date' },
      notes       => { class    => 'standard-field autosize',
                       disabled => $disabled, type => 'textarea' },
      ];
};

my $_history_list_ops_links = sub {
   my ($self, $req, $vrn, $opts, $pager) = @_; my $links = [];

   my $actionp = $self->moniker.'/history_list';
   my $page_links = page_link_set $req, $actionp, [], $opts, $pager;

   $page_links and push @{ $links }, $page_links;

   $actionp = $self->moniker.'/history_view';

   my $params = $_query_params_no_mid->( $req );
   my $href   = $req->uri_for_action( $actionp, [ $vrn ], $params );

   p_link $links, 'mileage_period', $href, $_create_action->( $req, $opts );

   return $links;
};

my $_history_list_row = sub {
   my ($self, $req, $params, $history) = @_; my $row = [];

   my $vrn     = $history->vehicle->vrn;
   my $actionp = $self->moniker.'/history_view';
   my $date    = local_dt( $history->period_start )->ymd;
   my $href    = $req->uri_for_action( $actionp, [ $vrn, $date ], $params );

   p_item $row, p_link {}, "${vrn}-history", $href, {
      request => $req,
      tip     => locm( $req, 'mileage_period_edit_tip', $vrn ),
      value   => month_label( $req, $history->period_start ) };

   p_item $row, $history->current_miles;

   return $row;
};

my $_history_list_uri_for = sub {
   my ($self, $req, $vrn) = @_;

   my $actionp = $self->moniker.'/history_list';
   my $params  = $_query_params_no_mid->( $req );

   return $req->uri_for_action( $actionp, [ $vrn ], $params );
};

my $_history_view_ops_links = sub {
   my ($self, $req, $vrn) = @_; my $links = [];

   my $href = $self->$_history_list_uri_for( $req, $vrn );

   p_link $links, 'vehicle_histories', $href, { request => $req };

   return $links;
};

my $_maybe_find_history = sub {
   my ($self, $vehicle, $hist_dt) = @_; $hist_dt or return Class::Null->new;

   my $hist_rs = $self->schema->resultset( 'VehicleHistory' );
   my $where   = { period_start => $hist_dt, vehicle_id => $vehicle->id };

   return $hist_rs->search( $where )->first;
};

my $_maybe_redirect_to_management = sub {
   my ($self, $req, $stash) = @_;

   my $params = $_query_params_no_mid->( $req );

   if ($params->{adhoc} or $params->{private} or $params->{service}) {
      my $actionp = $self->moniker.'/vehicles';
      my $location = $req->uri_for_action( $actionp, [], $params );

      $stash->{redirect}->{location} = $location;
   }

   return;
};

my $_toggle_event_assignment = sub {
   my ($self, $req, $action, $vrn) = @_;

   my $schema  = $self->schema;
   my $uri     = $req->uri_params->( 0 );
   my $event   = $schema->resultset( 'Event' )->find_event_by( $uri );
   my $vehicle = $schema->resultset( 'Vehicle' )->find_vehicle_by( $vrn );
   my $method  = $action eq 'assign'
               ? 'assign_to_event' : 'unassign_from_event';
   my $mode    = $req->session->allocation_mode;

   $vehicle->$method( $uri, $req->username, $mode );

   $mode eq BATCH_MODE
      or $self->send_event_assign_event( $req, $action, $vrn, $event );

   my $prep    = $action eq 'assign' ? 'to' : 'from';
   my $key     = "Vehicle [_1] ${action}ed ${prep} [_2] by [_3]";
   my $message = [ to_msg $key, $vrn, $uri, $req->session->user_label ];

   return { redirect => { message => $message } }; # location referer
};

my $_toggle_slot_assignment = sub {
   my ($self, $req, $action, $vrn) = @_;

   my $params     = $req->uri_params;
   my $rota_name  = $params->( 0 );
   my $rota_date  = $params->( 1 );
   my $slot_key   = $params->( 2 );
   my $vehicle_rs = $self->schema->resultset( 'Vehicle' );
   my $vehicle    = $vehicle_rs->find_vehicle_by( $vrn );
   my $method     = "${action}_slot"; # Assign or unassign
   my $rota_dt    = to_dt $rota_date;
   my $mode       = $req->session->allocation_mode;
   my $slot       = $vehicle->$method
      ( $rota_name, $rota_dt, $slot_key, $req->username, $mode );

   $mode eq BATCH_MODE
      or $self->send_slot_assign_event( $req, $action, $vrn, $slot );

   my $sr_map  = $self->config->slot_region;
   my $prep    = $action eq 'assign' ? 'to' : 'from';
   my $key     = "Vehicle [_1] ${action}ed ${prep} slot [_2] by [_3]";
   my $label   = slot_identifier $rota_name, $rota_date, $slot_key, $sr_map;
   my $message = [ to_msg $key, $vrn, $label, $req->session->user_label ];

   return { redirect => { message => $message } }; # location referer
};

my $_toggle_assignment = sub {
   my ($self, $req, $action) = @_; my $r;

   my $rota_name = $req->uri_params->( 0 );
   my $vrn = $req->body_params->( 'vehicle' );

   try   { $self->schema->resultset( 'Type' )->find_rota_by( $rota_name ) }
   catch { $r = $self->$_toggle_event_assignment( $req, $action, $vrn ) };

   $r and return $r;

   return $self->$_toggle_slot_assignment( $req, $action, $vrn );
};

my $_update_vehicle_from_request = sub {
   my ($self, $req, $vehicle) = @_; my $params = $req->body_params; my $v;

   my $opts = { optional => TRUE };

   for my $attr (qw( aquired colour disposed name notes vrn )) {
      if (is_member $attr, [ 'notes' ]) { $opts->{raw} = TRUE }
      else { delete $opts->{raw} }

      my $v = $params->( $attr, $opts ); defined $v or next;

      $v =~ s{ \r\n }{\n}gmx; $v =~ s{ \r }{\n}gmx;

      length $v and is_member $attr, [ qw( aquired disposed ) ]
         and $v = to_dt $v;

      $vehicle->$attr( $v );
   }

   $v = $params->( 'model', $opts ); $vehicle->model_id( $v ? $v : undef );
   $v = $params->( 'owner', $opts ); $vehicle->owner_id( $v ? $v : undef );
   $v = $params->( 'type',  $opts ); defined $v and $vehicle->type_id( $v );

   return;
};

my $_update_history_from_previous = sub {
   my ($self, $vehicle, $hist_rs, $current) = @_;

   my $where    =  { vehicle_id => $vehicle->id };
   my $opts     =  {
      order_by  => { '-desc' => 'period_start' },
      page      => 1,
      rows      => 1, };

   if (my $previous = $hist_rs->search( $where, $opts )->first) {
      for my $attr (@HISTORY_ATTR) { $current->$attr( $previous->$attr() ) }
   }
   else { $current->current_miles( 0 ) }

   return;
};

my $_update_history_from_request = sub {
   my ($self, $req, $history) = @_; my $params = $req->body_params;

   my $opts = { optional => TRUE };

   for my $attr (@HISTORY_ATTR) {
      my $v = $params->( $attr, $opts ); defined $v or next;

      $v =~ s{ \r\n }{\n}gmx; $v =~ s{ \r }{\n}gmx;

      length $v and is_member $attr,
         [ qw( insurance_due last_fueled mot_due next_service_due tax_due ) ]
            and $v = to_dt $v;

      $history->$attr( $v );
   }

   return;
};

my $_vehicle_events = sub {
   my ($self, $req, $opts) = @_; my @rows;

   my $event_rs = $self->schema->resultset( 'Event' );
   my $slot_rs  = $self->schema->resultset( 'Slot' );
   my $tport_rs = $self->schema->resultset( 'Transport' );

   for my $slot ($slot_rs->search_for_assigned_slots( $opts )->all) {
      push @rows,
         [ $slot,
           [ { value => $slot->label( $req ) },
             { value => $slot->operator->label },
             { value => $slot->start_time },
             { value => $slot->end_time },
             $self->$_vehicle_slot_links( $req, $slot ) ] ];
   }

   $opts->{prefetch} = [ 'end_rota', 'owner', 'location', 'start_rota' ];

   for my $event ($event_rs->search_for_events( $opts )->all) {
      push @rows,
         [ $event,
           [ { value => $event->label },
             { value => $event->owner->label },
             { value => $event->start_time },
             { value => $event->end_time },
             $self->$_vehicle_event_links( $req, $event ) ] ];
   }

   $opts->{prefetch} = [ {
      'event' => [ 'end_rota', 'owner', 'start_rota' ] }, 'vehicle' ];

   for my $tport ($tport_rs->search_for_assigned_vehicles( $opts )->all) {
      my $event = $tport->event;

      push @rows,
         [ $event,
           [ { value => $event->label },
             { value => $event->owner->label },
             { value => $event->start_time },
             { value => $event->end_time },
             $self->$_transport_links( $req, $event ) ] ];
   }

   my $compare = exists $opts->{before} ? $_compare_reverse : $_compare_forward;

   return [ sort { $compare->( $a, $b ) } @rows ];
};

my $_vehicle_ops_links = sub {
   my ($self, $req, $page, $vrn) = @_; my $links = [];

   my $params = $_query_params_no_mid->( $req );

   if ($vrn) {
      p_link $links, 'vehicle',
         $req->uri_for_action( $self->moniker.'/vehicle', [], $params ),
            $_create_action->( $req );
   }
   else {
      p_link $links, 'model', '#', {
         class   => 'windows',
         request => $req,
         tip     => locm( $req, 'vehicle_model_tip' ),
         value   => locm( $req, 'vehicle_model_add' ), };

      p_js $page, dialog_anchor 'model',
         $req->uri_for_action( $self->moniker.'/vehicle_model', [], $params ), {
            name => 'model', title => locm $req, 'vehicle_model_title' };
   }

   return $links;
};

my $_vehicles_row = sub {
   my ($self, $req, $params, $vehicle) = @_; my $row = [];

   my $vrn     = $vehicle->vrn;
   my $moniker = $self->moniker;
   my $href    = $req->uri_for_action( "${moniker}/vehicle", [ $vrn ], $params);

   p_item $row, p_link {}, "${vrn}-vehicle", $href, {
      request => $req,
      tip     => locm( $req, 'vehicle_management_tip', $vrn ),
      value   => $vehicle->label };

   p_item $row, locm $req, $vehicle->type;

   p_item $row, $vehicle->model ? $vehicle->model->label( $req ) : NUL;

   $params->{service} or return $row;

   my $now    = now_dt;
   my $keeper = $self->find_last_keeper( $req, $now, $vehicle );

   p_item $row, $keeper ? $keeper->[ 0 ]->label : NUL;

   p_item $row, management_link $req, "${moniker}/vehicle_events", $vrn, {
      params => { after => $now->subtract( days => 1 )->ymd } };

   $href = $self->$_history_list_uri_for( $req, $vrn );

   p_item $row, p_link {}, "${vrn}-vehicle-histories", $href, {
      request => $req,
      tip     => locm( $req, 'vehicle_histories_tip', $vrn ),
      value   => locm( $req, 'Mileage' ), };

   return $row;
};

my $_vehicles_ops_links = sub {
   my ($self, $req, $opts, $pager) = @_; my $links = [];

   my $actionp = $self->moniker.'/vehicles';
   my $page_links = page_link_set $req, $actionp, [], $opts, $pager;

   $page_links and push @{ $links }, $page_links;

   my @keys   = qw( adhoc private service );
   my %params = (); @params{ @keys } = @{ $opts }{ @keys };

   my $href = $req->uri_for_action( $self->moniker.'/vehicle', [], \%params );

   p_link $links, 'vehicle', $href, $_create_action->( $req, $opts );

   return $links;
};

# Public methods
sub adhoc_vehicle : Dialog Role(any) {
   my ($self, $req) = @_;

   my $stash  = $self->dialog_stash( $req );
   my $href   = $req->uri_for_action( $self->moniker.'/vehicle' );
   my $form   = $stash->{page}->{forms}->[ 0 ]
              = new_container 'adhoc-vehicle', $href;
   my $schema = $self->schema;
   my $values = [ [ NUL, undef ], @{ $_list_vehicle_types->( $schema, {} ) } ];

   p_textfield $form, 'vrn',    NUL;
   p_select    $form, 'type',   $values, {
      label => 'vehicle_type',  numify => TRUE };
   p_textarea  $form, 'notes',  NUL, { class => 'standard-field autosize' };
   p_action    $form, 'create', [ 'adhoc_vehicle' ], { request => $req };

   return $stash;
}

sub assign : Dialog Role(rota_manager) {
   my ($self, $req) = @_; my $params = $req->uri_params;

   my $args = [ $params->( 0 ) ]; my $opts = { optional => TRUE };

   my $rota_date = $params->( 1, $opts );
      $rota_date and push @{ $args }, $rota_date;

   my $slot_name = $params->( 2, $opts );
      $slot_name and push @{ $args }, $slot_name;

   my $action = $req->query_params->( 'action' );
   my $type   = $req->query_params->( 'type', {
      multiple => TRUE, optional => TRUE } ) // [ 'bike' ];

   my $stash  = $self->dialog_stash( $req );
   my $href   = $req->uri_for_action( $self->moniker.'/vehicle', $args );
   my $form   = $stash->{page}->{forms}->[ 0 ]
              = new_container "${action}-vehicle", $href;
   my $page   = $stash->{page};

   if ($action eq 'assign') {
      my $rs       = $self->schema->resultset( 'Vehicle' );
      my $where    = { service => TRUE, type => $type };
      my $vehicles = $rs->list_vehicles( $where );
      my $mode     = $req->query_params->( 'mode', { optional => TRUE }) // NUL;

      $mode eq 'slow' and $vehicles = $self->components->{week}->filter_vehicles
         ( $req, $args, $vehicles );

      p_select $form, 'vehicle', [ [ NUL, NUL ], @{ $vehicles } ], {
         class => 'right-last', label => NUL };
      p_js $page, set_element_focus 'assign-vehicle', 'vehicle';
   }
   else { p_hidden $form, 'vehicle', $req->query_params->( 'vehicle' ) }

   p_button $form, 'confirm', "${action}_vehicle", {
      class => 'button right-last' };

   return $stash;
}

sub assign_vehicle_action : Role(rota_manager) {
   return $_[ 0 ]->$_toggle_assignment( $_[ 1 ], 'assign' );
}

sub create_adhoc_vehicle_action : Role(controller) Role(driver) Role(rider)
                                  Role(rota_manager) {
   return $_[ 0 ]->create_vehicle_action( $_[ 1 ] );
}

sub create_mileage_period_action : Role(rota_manager) {
   my ($self, $req) = @_;

   my $vrn      = $req->uri_params->( 0 );
   my $date     = $req->body_params->( 'period_start' );
   my $hist_dt  = to_dt $date;
   my $schema   = $self->schema;
   my $vehicle  = $schema->resultset( 'Vehicle' )->find_vehicle_by( $vrn );
   my $hist_rs  = $schema->resultset( 'VehicleHistory' );
   my $history  = $hist_rs->new_result( {
      period_start => $hist_dt, vehicle_id => $vehicle->id } );

   $self->$_update_history_from_previous( $vehicle, $hist_rs, $history );

   try   { $history->insert }
   catch { $self->blow_smoke( $_, 'create', 'mileage period', $vrn ) };

   my $who      = $req->session->user_label;
   my $message  = [ to_msg 'Mileage period [_1] [_2] created by [_3]',
                    $vrn, month_label( $req, $hist_dt ), $who ];
   my $location = $self->$_history_list_uri_for( $req, $vrn );

   return { redirect => { location => $location, message => $message } };
}

sub create_vehicle_action : Role(rota_manager) {
   my ($self, $req) = @_;

   my $vehicle = $self->schema->resultset( 'Vehicle' )->new_result( {} );

   $self->$_update_vehicle_from_request( $req, $vehicle );

   try   { $vehicle->insert }
   catch { $self->blow_smoke( $_, 'create', 'vehicle', $vehicle->vrn ) };

   my $vrn = $vehicle->vrn;

   $self->send_event( $req, "action:create-vehicle vehicle:${vrn}" );

   my $who = $req->session->user_label;
   my $message = [ to_msg 'Vehicle [_1] created by [_2]', $vrn, $who ];
   my $stash = { redirect => { message => $message } }; # location referer

   $self->$_maybe_redirect_to_management( $req, $stash );

   return $stash;
}

sub create_vehicle_model_action : Role(rota_manager) {
   my ($self, $req) = @_;

   my $stash  = $self->components->{admin}->add_type_action( $req );
   my $params = $_query_params_no_mid->( $req );
   my $href   = $req->uri_for_action( $self->moniker.'/vehicle', [], $params );

   $stash->{redirect}->{location} = $href;

   return $stash;
}

sub delete_mileage_period_action : Role(rota_manager) {
   my ($self, $req) = @_;

   my $vrn      = $req->uri_params->( 0 );
   my $date     = $req->uri_params->( 1 );
   my $hist_dt  = to_dt $date;
   my $schema   = $self->schema;
   my $vehicle  = $schema->resultset( 'Vehicle' )->find_vehicle_by( $vrn );
   my $who      = $req->session->user_label;
   my $args     = [ $vrn, month_label( $req, $hist_dt ), $who ];
   my $history  = $self->$_maybe_find_history( $vehicle, $hist_dt )
      or throw 'Mileage period [_1] [_2] not found', $args;

   $history->delete;

   my $key      = 'Mileage period [_1] [_2] deleted by [_3]';
   my $message  = [ to_msg $key, @{ $args } ];
   my $location = $self->$_history_list_uri_for( $req, $vrn );

   return { redirect => { location => $location, message => $message } };
}

sub delete_vehicle_action : Role(rota_manager) {
   my ($self, $req) = @_;

   my $vrn     = $req->uri_params->( 0 );
   my $vehicle = $self->schema->resultset( 'Vehicle' )->find_vehicle_by( $vrn );

   $vehicle->delete;

   my $who      = $req->session->user_label;
   my $actionp  = $self->moniker.'/vehicles';
   my $params   = $_query_params_no_mid->( $req );
   my $location = $req->uri_for_action( $actionp, [], $params );
   my $message  = [ to_msg 'Vehicle [_1] deleted by [_2]', $vrn, $who ];

   $self->send_event( $req, "action:delete-vehicle vehicle:${vrn}" );

   return { redirect => { location => $location, message => $message } };
}

sub find_last_keeper {
   my ($self, $req, $now, $vehicle) = @_; my $keeper;

   my $tommorrow = $now->clone->truncate( to => 'day' )->add( days => 1 );
   my $opts      = { before     => $tommorrow,
                     event_type => 'vehicle',
                     page       => 1,
                     vehicle    => $vehicle->vrn,
                     rows       => 10, };

   for my $tuple (@{ $self->$_vehicle_events( $req, $opts ) }) {
      my ($start_dt) = $tuple->[ 0 ]->duration; $start_dt > $now and next;

      my $attr = $tuple->[ 0 ]->can( 'owner' ) ? 'owner' : 'operator';
      my $event; $attr eq 'owner' and $event = $tuple->[ 0 ];

      my $location; $event and $event->event_type eq 'vehicle'
         and $location = $event->location;

      $keeper = [ $tuple->[ 0 ]->$attr(), $location ]; last;
   }

   return $keeper;
}

sub history_list : Role(rota_manager) {
   my ($self, $req) = @_;

   my $vrn       =  $req->uri_params->( 0 );
   my $params    =  $_query_params_no_mid->( $req );
   my $form      =  new_container;
   my $page      =  {
      forms      => [ $form ],
      selected   => $_select_nav_link_name->( $params ),
      title      => locm $req, 'vehicle_histories_title', };
   my $schema    =  $self->schema;
   my $vehicle   =  $schema->resultset( 'Vehicle' )->find_vehicle_by( $vrn );
   my $hist_rs   =  $schema->resultset( 'VehicleHistory' );
   my $opts      =  {
      order_by   => { '-desc' => 'period_start' },
      page       => $params->{page} || 1,
      rows       => $req->session->rows_per_page, };
   my $histories =  $hist_rs->search( { vehicle_id => $vehicle->id }, $opts );
   my $links     =  $self->$_history_list_ops_links
      ( $req, $vrn, $opts, $histories->pager );

   p_textfield $form, 'vehicle', $vehicle->label, { disabled => TRUE };
   p_list      $form, PIPE_SEP, $links, link_options 'right';

   my $table = p_table $form, { headers => $_history_list_headers->( $req ) };

   p_row $table, [ map { $self->$_history_list_row( $req, $params, $_ ) }
                   $histories->all ];

   return $self->get_stash( $req, $page );
}

sub history_view : Role(rota_manager) {
   my ($self, $req) = @_;

   my $vrn     =  $req->uri_params->( 0 );
   my $date    =  $req->uri_params->( 1, { optional => TRUE } );
   my $hist_dt =  $date ? to_dt $date : undef;
   my $actionp =  $self->moniker.'/history_view';
   my $params  =  $_query_params_no_mid->( $req );
   my $href    =  $req->uri_for_action( $actionp, [ $vrn, $date ], $params );
   my $form    =  new_container 'history-view', $href;
   my $page    =  {
      forms    => [ $form ],
      selected => $_select_nav_link_name->( $params ),
      title    => locm $req, 'vehicle_history_title', };
   my $schema  =  $self->schema;
   my $vehicle =  $schema->resultset( 'Vehicle' )->find_vehicle_by( $vrn );
   my $links   =  $self->$_history_view_ops_links( $req, $vrn );
   my $history =  $self->$_maybe_find_history( $vehicle, $hist_dt );
   my $fields  =  $self->$_bind_history_fields( $req, $history, $params );
   my $args    =  [ 'mileage_period', $history->label( $req ) ];
   my $action  =  $date ? 'update' : 'create';
   my $first   =  $date ? 'current_miles' : 'period_start';

   p_js        $page, set_element_focus 'history-view', $first;
   p_list      $form, PIPE_SEP, $links, link_options 'right';
   p_textfield $form, 'vehicle', $vehicle->label, { disabled => TRUE };
   p_fields    $form, $schema, 'VehicleHistory', $history, $fields;
   p_action    $form, $action, $args, { request => $req };

   $date and p_action $form, 'delete', $args, { request => $req };

   return $self->get_stash( $req, $page );
}

sub request_info : Dialog Role(rota_manager) {
   my ($self, $req) = @_;

   my $uri     = $req->uri_params->( 0 );
   my $event   = $self->schema->resultset( 'Event' )->find_event_by( $uri );
   my $stash   = $self->dialog_stash( $req );
   my $vreq_rs = $self->schema->resultset( 'VehicleRequest' );
   my $form    = $stash->{page}->{forms}->[ 0 ] = new_container;
   my $id      = $event->id;

   my ($start, $end) = display_duration $req, $event;

   p_tag $form, 'p', $event->name;
   p_tag $form, 'p', $start; p_tag $form, 'p', $end;

   for my $tuple ($vreq_rs->search_for_request_info( { event_id => $id } )) {
      p_tag $form, 'p', $tuple->[ 1 ].' x '.loc( $req, $tuple->[ 0 ]->type );
   }

   return $stash;
}

sub request_vehicle : Role(rota_manager) Role(event_manager) {
   my ($self, $req) = @_;

   my $schema   =  $self->schema;
   my $uri      =  $req->uri_params->( 0 );
   my $event    =  $schema->resultset( 'Event' )->find_event_by
                   ( $uri, { prefetch => [ 'owner' ] } );
   my $href     =  $req->uri_for_action( $self->moniker.'/vehicle', [ $uri ] );
   my $form     =  new_container 'vehicle-request', $href, {
      class     => 'wide-form no-header-wrap' };
   my $selected =  $event->event_type eq 'training' ? 'training_events'
                :  now_dt > $event->start_date      ? 'previous_events'
                :                                     'current_events';
   my $disabled =  $selected eq 'previous_events' ? TRUE : FALSE;
   my $page     =  {
      disabled  => $disabled,
      event_uri => $uri,
      forms     => [ $form ],
      location  => 'events',
      moniker   => $self->moniker,
      selected  => $selected,
      title     => loc $req, 'vehicle_request_heading' };
   my $type_rs  =  $schema->resultset( 'Type' );

   p_textfield $form, 'name', $event->name, {
      disabled => TRUE, label => 'event_name' };

   p_date $form, 'start_date', $event->start_date, { disabled => TRUE };

   my $links = []; $href = $req->uri_for_action( 'event/event', [ $uri ] );

   p_link $links, 'edit_event', $href, {
      container_class => 'table-link', request => $req };

   p_list $form, PIPE_SEP, $links, link_options 'right';

   my $table = p_table $form, { headers => $_vehicle_request_headers->( $req )};

   p_row $table, [ map { $_vreq_row->( $schema, $req, $page, $event, $_ ) }
                   $type_rs->search_for_vehicle_types->all ];

   not $disabled and p_button $form, 'request_vehicle', 'request_vehicle', {
      class => 'save-button right-last' };

   my $stash = $self->get_stash( $req, $page );

   $stash->{navigation} = $self->events_navigation_links( $req, $page );

   return $stash;
}

sub request_vehicle_action : Role(event_manager) {
   my ($self, $req) = @_;

   my $schema  = $self->schema;
   my $uri     = $req->uri_params->( 0 );
   my $event   = $schema->resultset( 'Event' )->find_event_by( $uri );
   my $type_rs = $schema->resultset( 'Type' );

   for my $vehicle_type ($type_rs->search_for_types( 'vehicle' )->all) {
      my $vreq = $_find_or_create_vreq->( $schema, $event, $vehicle_type );

      $_update_vehicle_req_from_request->( $req, $vreq, $vehicle_type );

      if ($vreq->in_storage) { $vreq->update } else { $vreq->insert }

      my $quantity = $vreq->quantity // 0;
      my $message  = "action:request-vehicle event_uri:${uri} "
                   . "vehicletype:${vehicle_type} quantity:${quantity}";

      $quantity > 0 and $self->send_event( $req, $message );
   }

   my $actionp  = $self->moniker.'/request_vehicle';
   my $location = $req->uri_for_action( $actionp, [ $uri ] );
   my $message  = [ to_msg 'Vehicle request for event [_1] updated by [_2]',
                    $event->label, $req->session->user_label ];

   return { redirect => { location => $location, message => $message } };
}

sub send_event_assign_event {
   my ($self, $req, $action, $vrn, $event) = @_;

   my $uri       = $event->uri;
   my $scode     = $event->owner;
   my $local_dmy = locd $req, $event->start_date;
   my $kv        = $action eq 'assign' ? 'action:vehicle-assignment'
                                       : 'action:vehicle-unassignment';
   my $message   = "${kv} date:${local_dmy} event_uri:${uri} "
                 . "shortcode:${scode} vehicle:${vrn}";

   return $self->send_event( $req, $message );
}

sub send_slot_assign_event {
   my ($self, $req, $action, $vrn, $slot) = @_;

   my $slot_key  = $slot->key;
   my $scode     = $slot->operator;
   my $local_dmy = locd $req, $slot->start_date;
   my $kv        = $action eq 'assign' ? 'action:vehicle-assignment'
                                       : 'action:vehicle-unassignment';
   my $message   = "${kv} date:${local_dmy} slot_key:${slot_key} "
                 . "shortcode:${scode} vehicle:${vrn}";

   return $self->send_event( $req, $message );
}

sub unassign_vehicle_action : Role(rota_manager) {
   return $_[ 0 ]->$_toggle_assignment( $_[ 1 ], 'unassign' );
}

sub update_mileage_period_action : Role(rota_manager) {
   my ($self, $req) = @_;

   my $vrn     = $req->uri_params->( 0 );
   my $date    = $req->uri_params->( 1 );
   my $hist_dt = to_dt $date;
   my $schema  = $self->schema;
   my $vehicle = $schema->resultset( 'Vehicle' )->find_vehicle_by( $vrn );
   my $who     = $req->session->user_label;
   my $args    = [ $vrn, month_label( $req, $hist_dt ), $who ];
   my $history = $self->$_maybe_find_history( $vehicle, $hist_dt )
      or throw 'Mileage period [_1] [_2] not found', $args;

   $self->$_update_history_from_request( $req, $history );

   try   { $history->update }
   catch { $self->blow_smoke( $_, 'update', 'mileage period', $vrn ) };

   my $key      = 'Mileage period [_1] [_2] updated by [_3]';
   my $message  = [ to_msg $key, @{ $args } ];
   my $location = $self->$_history_list_uri_for( $req, $vrn );

   return { redirect => { location => $location, message => $message } };
};

sub update_vehicle_action : Role(rota_manager) {
   my ($self, $req) = @_;

   my $vrn     = $req->uri_params->( 0 );
   my $vehicle = $self->schema->resultset( 'Vehicle' )->find_vehicle_by( $vrn );

   $self->$_update_vehicle_from_request( $req, $vehicle );

   try   { $vehicle->update }
   catch { $self->blow_smoke( $_, 'update', 'vehicle', $vehicle->vrn ) };

   my $who      = $req->session->user_label; $vrn = $vehicle->vrn;
   my $actionp  = $self->moniker.'/vehicles';
   my $params   = $_query_params_no_mid->( $req );
   my $location = $req->uri_for_action( $actionp, [], $params );
   my $message  = [ to_msg 'Vehicle [_1] updated by [_2]', $vrn, $who ];

   $self->send_event( $req, "action:update-vehicle vehicle:${vrn}" );

   return { redirect => { location => $location, message => $message } };
}

sub vehicle : Role(rota_manager) {
   my ($self, $req) = @_;

   my $actionp    =  $self->moniker.'/vehicle';
   my $params     =  $_query_params_no_mid->( $req );
   my $vrn        =  $req->uri_params->( 0, { optional => TRUE } );
   my $href       =  $req->uri_for_action( $actionp, [ $vrn ], $params );
   my $form       =  new_container 'vehicle-admin', $href;
   my $action     =  $vrn ? 'update' : 'create';
   my $page       =  {
      first_field => 'vrn',
      forms       => [ $form ],
      selected    => $_select_nav_link_name->( $params ),
      title       => loc $req, "vehicle_${action}_heading" };
   my $vehicle    =  $_maybe_find_vehicle->( $self->schema, $vrn );
   my $fields     =  $self->$_bind_vehicle_fields( $req, $vehicle, $params );
   my $args       =  [ 'vehicle', $vehicle->label ];
   my $links      =  $self->$_vehicle_ops_links( $req, $page, $vrn );

   p_js $page, $_vehicle_js->( $vrn );

   p_list $form, PIPE_SEP, $links, link_options 'right';

   p_fields $form, $self->schema, 'Vehicle', $vehicle, $fields;

   p_action $form, $action, $args, { request => $req };

   $vrn and p_action $form, 'delete', $args, { request => $req };

   return $self->get_stash( $req, $page );
}

sub vehicle_events : Role(rota_manager) {
   my ($self, $req) = @_;

   my $vrn    =  $req->uri_params->( 0 );
   my $params =  $_query_params_no_mid->( $req );
   my $after  =  $params->( 'after',  { optional => TRUE } );
   my $before =  $params->( 'before', { optional => TRUE } );
# TODO: Add paged query in case of search for vehicle event before tommorrow
   my $opts   =  { after      => $after  ? to_dt( $after  ) : FALSE,
                   before     => $before ? to_dt( $before ) : FALSE,
                   event_type => 'vehicle',
                   vehicle    => $vrn, };
   my $form   =  new_container { class => 'wide-form no-header-wrap' };
   my $page   =  {
      forms   => [ $form ], selected => 'service_vehicles',
      title   => loc $req, 'vehicle_events_management_heading' };

   p_textfield $form, 'vehicle', $vrn, { disabled => TRUE };

   my $links  = [];
   my $href   = $req->uri_for_action( 'event/vehicle_event', [ $vrn ] );

   p_link $links, 'event', $href, $_create_action->( $req );

   p_list $form, PIPE_SEP, $links, link_options 'right';

   my $table  = p_table $form, { headers => $_vehicle_events_headers->( $req )};
   my $events = $self->$_vehicle_events( $req, $opts );

   p_row $table, [ map { $_->[ 1 ] } @{ $events } ];

   return $self->get_stash( $req, $page );
}

sub vehicle_model : Dialog Role(rota_manager) {
   my ($self, $req) = @_;

   my $stash   = $self->dialog_stash( $req );
   my $actionp = $self->moniker.'/vehicle_model';
   my $params  = $_query_params_no_mid->( $req );
   my $href    = $req->uri_for_action( $actionp, [ 'vehicle_model' ], $params );
   my $form    = $stash->{page}->{forms}->[ 0 ]
               = new_container 'vehicle-model', $href;

   p_textfield $form, 'name', NUL;
   p_action    $form, 'create', [ 'vehicle_model' ], { request => $req };

   return $stash;
}

sub vehicles : Role(controller) Role(rota_manager) {
   my ($self, $req) = @_;

   my $moniker  =  $self->moniker;
   my $params   =  $_query_params_no_mid->( $req );
   my $opts     =  {
      adhoc     => $params->{adhoc  } || FALSE,
      page      => $params->{page   } || 1,
      private   => $params->{private} || FALSE,
      rows      => $req->session->rows_per_page,
      service   => $params->{service} || FALSE,
      type      => $params->{type   } };
   my $v_rs     =  $self->schema->resultset( 'Vehicle' );
   my $vehicles =  $v_rs->search_for_vehicles( $opts );
   my $form     =  new_container;
   my $page     =  {
      forms     => [ $form ],
      selected  => $_select_nav_link_name->( $params ),
      title     => $_vehicle_title->( $req, $params ), };
   my $links    =  $self->$_vehicles_ops_links( $req, $opts, $vehicles->pager );

   p_list $form, PIPE_SEP, $links, link_options 'right';

   my $table = p_table $form, {
      headers => $_vehicles_headers->( $req, $params ) };

   p_row $table, [ map { $self->$_vehicles_row( $req, $params, $_ ) }
                   $vehicles->all ];

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
