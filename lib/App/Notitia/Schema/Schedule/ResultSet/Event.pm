package App::Notitia::Schema::Schedule::ResultSet::Event;

use strictures;
use parent 'DBIx::Class::ResultSet';

use App::Notitia::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use App::Notitia::Util      qw( local_dt set_event_date set_rota_date );
use Class::Usul::Functions  qw( is_member throw );

# Private methods
my $_find_course_type = sub {
   my ($self, $course_name) = @_; my $schema = $self->result_source->schema;

   return $schema->resultset( 'Type' )->find_course_by( $course_name );
};

my $_find_event_type = sub {
   my ($self, $type_name) = @_; my $schema = $self->result_source->schema;

   return $schema->resultset( 'Type' )->find_event_by( $type_name );
};

my $_find_owner = sub {
   my ($self, $scode) = @_; my $schema = $self->result_source->schema;

   my $opts = { columns => [ 'id' ] };

   return $schema->resultset( 'Person' )->find_by_shortcode( $scode, $opts );
};

my $_find_rota = sub {
   return $_[ 0 ]->result_source->schema->resultset( 'Rota' )->find_rota
      (   $_[ 1 ], $_[ 2 ] );
};

my $_find_vehicle = sub {
   my ($self, $vrn) = @_; my $schema = $self->result_source->schema;

   return $schema->resultset( 'Vehicle' )->find_vehicle_by( $vrn );
};

# Public methods
sub new_result {
   my ($self, $columns) = @_;

   my $name = delete $columns->{rota}; my $date = delete $columns->{start_date};

   $name and $date
         and $columns->{start_rota_id} = $self->$_find_rota( $name, $date )->id;

   $date = delete $columns->{end_date};

   $name and $date
         and $columns->{end_rota_id} = $self->$_find_rota( $name, $date )->id;

   my $type = delete $columns->{event_type};

   $type and $columns->{event_type_id} = $self->$_find_event_type( $type )->id;

   my $owner = delete $columns->{owner};

   $owner and $columns->{owner_id} = $self->$_find_owner( $owner )->id;

   my $vrn = delete $columns->{vehicle};

   $vrn and $columns->{vehicle_id} = $self->$_find_vehicle( $vrn )->id;

   my $course = delete $columns->{course_type};

   $course
      and $columns->{course_type_id} = $self->$_find_course_type( $course )->id;

   return $self->next::method( $columns );
}

sub find_event_by {
   my ($self, $uri, $opts) = @_; $opts //= {};

   $opts->{prefetch} //= []; push @{ $opts->{prefetch} }, 'start_rota';

   my $event = $self->search( { uri => $uri }, $opts )->single;

   defined $event or throw 'Event [_1] unknown', [ $uri ], level => 2;

   return $event;
}

sub has_events_for {
   my ($self, $opts) = @_; my $has_event = {}; $opts = { %{ $opts } };

   my $where    = { 'event_type.name'    => $opts->{event_type} // 'person',
                    'start_rota.type_id' => $opts->{rota_type}, };
   my $parser   = $self->result_source->schema->datetime_parser;
   my $prefetch = [ 'start_rota', 'event_type' ];

   set_rota_date $parser, $where, 'start_rota.date', $opts;

   for my $event ($self->search( $where, { prefetch => $prefetch } )->all) {
      my $key = local_dt( $event->start_date )->ymd;

      $has_event->{ $key } //= []; push @{ $has_event->{ $key } }, $event;
   }

   return $has_event;
}

sub search_for_a_days_events {
   my ($self, $rota_type_id, $start_date, $opts) = @_; $opts //= {};

   my $parser = $self->result_source->schema->datetime_parser;

   return $self->search
      ( { 'event_type.name'    => $opts->{event_type} // 'person',
          'start_rota.type_id' => $rota_type_id,
          'start_rota.date'    => $parser->format_datetime( $start_date ) },
        { columns => [ 'id', 'name', 'start_rota.date',
                       'start_rota.type_id', 'uri' ],
          join    => [ 'start_rota', 'event_type' ] } );
}

sub search_for_events {
   my ($self, $opts) = @_; my $where = {}; $opts = { %{ $opts // {} } };

   delete $opts->{fields}; delete $opts->{rota_type};

   my $type     = delete $opts->{event_type};
      $type and $where->{ 'event_type.name' } = $type;
   my $vrn      = delete $opts->{vehicle};
      $vrn  and $where->{ 'vehicle.vrn' } = $vrn;
   my $prefetch = delete $opts->{prefetch} // [ 'end_rota', 'start_rota' ];
   my $parser = $self->result_source->schema->datetime_parser;

   set_event_date $parser, $where, $opts;
   $opts->{order_by} //= { -desc => 'start_rota.date' };
   $type and push @{ $prefetch }, 'event_type';
   $vrn  and not is_member 'vehicle', $prefetch
         and push @{ $prefetch }, 'vehicle';

   return $self->search
      ( $where, { columns  => [ 'id', 'end_time', 'name', 'start_time', 'uri' ],
                  prefetch => $prefetch, %{ $opts } } );
}

sub search_for_vehicle_events {
   my ($self, $opts) = @_; $opts = { %{ $opts } };

   $opts->{event_type}   = 'vehicle';
   $opts->{prefetch  } //= [ 'end_rota', 'start_rota', 'vehicle' ];

   return $self->search_for_events( $opts );
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Notitia::Schema::Schedule::ResultSet::Event - People and resource scheduling

=head1 Synopsis

   use App::Notitia::Schema::Schedule::ResultSet::Event;
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
