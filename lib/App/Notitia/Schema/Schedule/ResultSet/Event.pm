package App::Notitia::Schema::Schedule::ResultSet::Event;

use strictures;
use parent 'DBIx::Class::ResultSet';

use App::Notitia::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Class::Usul::Functions  qw( throw );
use HTTP::Status            qw( HTTP_EXPECTATION_FAILED );

# Private functions
my $_field_tuple = sub {
   my ($event, $opts) = @_; $opts = { %{ $opts // {} } };

   $opts->{selected} //= NUL;
   $opts->{selected}   = $opts->{selected} eq $event ? TRUE : FALSE;

   return [ $event->label, $event, $opts ];
};

# Private methods
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

   return $self->next::method( $columns );
}

sub count_events_for {
   my ($self, $rota_type_id, $start_rota_date, $event_type) = @_;

   $event_type //= 'person';

   return $self->count
      ( { 'event_type.name'    => $event_type,
          'start_rota.type_id' => $rota_type_id,
          'start_rota.date'    => $start_rota_date },
        { join                 => [ 'start_rota', 'event_type' ] } );
}

sub find_event_by {
   my ($self, $uri, $opts) = @_; $opts //= {};

   $opts->{prefetch} //= []; push @{ $opts->{prefetch} }, 'start_rota';

   my $event = $self->search( { uri => $uri }, $opts )->single;

   defined $event or throw 'Event [_1] unknown', [ $uri ],
                           level => 2, rv => HTTP_EXPECTATION_FAILED;

   return $event;
}

sub find_events_for {
   my ($self, $rota_type_id, $start_rota_date, $event_type) = @_;

   $event_type //= 'person';

   return $self->search
      ( { 'event_type.name'    => $event_type,
          'start_rota.type_id' => $rota_type_id,
          'start_rota.date'    => $start_rota_date },
        { columns => [ 'id', 'name', 'start_rota.date',
                       'start_rota.type_id', 'uri' ],
          join    => [ 'start_rota', 'event_type' ] } );
}

sub list_all_events {
   my ($self, $opts) = @_; $opts = { %{ $opts // {} } };

   my $type   = delete $opts->{event_type} // 'person';
   my $where  = { 'event_type.name' => $type };
   my $parser = $self->result_source->schema->datetime_parser;
   my $after  = delete $opts->{after}; my $before = delete $opts->{before};

   if ($after) {
      $where = { 'start_rota.date' =>
                 { '>' => $parser->format_datetime( $after ) } };
      $opts->{order_by} //= 'date';
   }
   elsif ($before) {
      $where = { 'start_rota.date' =>
                 { '<' => $parser->format_datetime( $before ) }};
   }

   $opts->{order_by} //= { -desc => 'date' };

   my $fields = delete $opts->{fields} // {};
   my $events = $self->search
      ( $where, { columns  => [ 'name', 'uri' ],
                  prefetch => [ 'event_type', 'start_rota' ], %{ $opts } } );

   return [ map { $_field_tuple->( $_, $fields ) } $events->all ];
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
