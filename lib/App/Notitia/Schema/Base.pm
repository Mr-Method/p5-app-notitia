package App::Notitia::Schema::Base;

use strictures;
use parent 'DBIx::Class::Core';

use App::Notitia::Constants qw( NUL TRUE );
use App::Notitia::Util      qw( assert_unique to_dt );
use Class::Usul::Functions  qw( throw );
use Data::Validation;

__PACKAGE__->load_components( qw( InflateColumn::Object::Enum TimeStamp ) );

sub assert_not_assigned_to_event {
   my ($self, $event, $opts) = @_;

   my ($event_start, $event_end) = $event->duration;
   my $tport_rs = $self->result_source->schema->resultset( 'Transport' );

   for my $tport ($tport_rs->search_for_assigned_vehicles( $opts )->all) {
      $tport->event_id == $event->id
         and throw 'Vehicle [_1] already assigned to this event',
                   [ $opts->{vehicle} ], level => 2;

      my ($tport_ev_start, $tport_ev_end) = $tport->event->duration;

      $tport_ev_end <= $event_start    and next;
      $event_end    <= $tport_ev_start and next;

      throw 'Vehicle [_1] already assigned to the [_2] event',
            [ $opts->{vehicle}, $tport->event ], level => 2;
   }

   return;
}

sub assert_not_assigned_to_slot {
   my ($self, $event, $opts) = @_;

   my ($event_start, $event_end) = $event->duration;
   my $slots_rs = $self->result_source->schema->resultset( 'Slot' );
   my $date     = $event->start_date->set_time_zone( 'local' )->ymd;

   for my $slot ($slots_rs->search_for_assigned_slots( $opts )->all) {
      my $type_name = $slot->shift->type_name;
      my ($shift_start, $shift_end) = $self->shift_times( $date, $type_name );

      $shift_end <= $event_start and next; $event_end <= $shift_start and next;

      throw 'Vehicle [_1] already assigned to slot [_2]',
            [ $opts->{vehicle}, $slot ], level => 2;
   }

   return;
}

sub assert_not_assigned_to_vehicle_event {
   my ($self, $event, $opts) = @_;

   my ($event_start, $event_end) = $event->duration;
   my $event_rs = $self->result_source->schema->resultset( 'Event' );

   for my $vehicle_event ($event_rs->search_for_vehicle_events( $opts )->all) {
      my ($vehicle_ev_start, $vehicle_ev_end) = $vehicle_event->duration;

      $vehicle_ev_end <= $event_start      and next;
      $event_end      <= $vehicle_ev_start and next;

      throw 'Vehicle [_1] already assigned to the [_2] vehicle event',
            [ $opts->{vehicle}, $vehicle_event ], level => 2;
   }

   return;
}

sub find_shift {
   my ($self, $rota_name, $date, $shift_type) = @_;

   my $schema = $self->result_source->schema;
   my $rota   = $schema->resultset( 'Rota' )->find_rota( $rota_name, $date );

   return $schema->resultset( 'Shift' )->find_or_create
      ( { rota_id => $rota->id, type_name => $shift_type } );
}

sub find_slot {
   my ($self, $shift, $slot_type, $subslot) = @_;

   my $slot_rs = $self->result_source->schema->resultset( 'Slot' );

   return $slot_rs->find_slot_by( $shift, $slot_type, $subslot );
}

sub shift_times {
   my ($self, $date, $shift_type) = @_;

   my $shift_times = $self->result_source->schema->config->shift_times;
   my $start_time  = $shift_times->{ "${shift_type}_start" };
   my $end_time    = $shift_times->{ "${shift_type}_end" };
   my $shift_start = to_dt "${date} ${start_time}";
   my $shift_end   = to_dt "${date} ${end_time}";

   $shift_end < $shift_start and $shift_end->add( days => 1 );

   return $shift_start, $shift_end;
}

sub validate {
   my ($self, $for_update) = @_; my $attr = $self->validation_attributes;

   defined $attr->{fields} or return TRUE;

   my $columns = { $self->get_inflated_columns };
   my $rs      = $self->result_source->resultset;

   for my $field (keys %{ $attr->{fields} }) {
      $attr->{fields}->{ $field }->{unique}
         and not $for_update
         and exists $columns->{ $field }
         and assert_unique $rs, $columns, $attr->{fields}, $field;

      my $valids =  $attr->{fields}->{ $field }->{validate} or next;
         $valids =~ m{ isMandatory }msx and $columns->{ $field } //= undef;
   }

   $columns = Data::Validation->new( $attr )->check_form( NUL, $columns );
   $self->set_inflated_columns( $columns );
   return TRUE;
}

sub validation_attributes {
   return {};
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Notitia::Schema::Base - People and resource scheduling

=head1 Synopsis

   use App::Notitia::Schema::Base;
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
