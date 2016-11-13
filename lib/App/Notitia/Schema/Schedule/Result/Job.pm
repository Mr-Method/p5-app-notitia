package App::Notitia::Schema::Schedule::Result::Job;

use strictures;
use overload '""' => sub { $_[ 0 ]->_as_string }, fallback => 1;
use parent 'App::Notitia::Schema::Base';

use App::Notitia::Constants qw( TRUE );
use App::Notitia::DataTypes qw( date_data_type numerical_id_data_type
                                serial_data_type
                                set_on_create_datetime_data_type
                                varchar_data_type );

my $class = __PACKAGE__; my $result = 'App::Notitia::Schema::Schedule::Result';

$class->table( 'job' );

$class->add_columns
   ( id       => serial_data_type,
     name     => varchar_data_type( 32 ),
     created  => set_on_create_datetime_data_type,
     updated  => date_data_type,
     run      => numerical_id_data_type( 0 ),
     max_runs => numerical_id_data_type( 3 ),
     period   => numerical_id_data_type( 300 ),
     command  => varchar_data_type( 1024 ),
     );

$class->set_primary_key( 'id' );

# Private methods
sub _as_string {
   return $_[ 0 ]->name.'-'.$_[ 0 ]->id;
}

# Public methods
sub insert {
   my $self = shift;

   App::Notitia->env_var( 'bulk_insert' ) or $self->validate;

   my $job = $self->next::method;
   my $jobdaemon = $self->result_source->schema->application->jobdaemon;

   $jobdaemon->is_running and $jobdaemon->trigger;

   return $job;
}

sub label {
   return $_[ 0 ]->_as_string;
}

sub update {
   my ($self, $columns) = @_;

   $columns and $self->set_inflated_columns( $columns );
   $self->validate( TRUE );

   return $self->next::method;
}

sub validation_attributes {
   return { # Keys: constraints, fields, and filters (all hashes)
      constraints => {
         command  => { max_length => 1024, min_length => 1, },
         name     => { max_length =>   32, min_length => 3, },
      },
      fields         => {
         command     => { validate => 'isMandatory isValidLength' },
         created     => { validate => 'isVaidDate' },
         max_runs    => { validate => 'isVaidInteger' },
         name        => {
            validate => 'isMandatory isValidLength isValidIdentifier', },
         period      => { validate => 'isVaidInteger' },
         run         => { validate => 'isVaidInteger' },
         updated     => { validate => 'isVaidDate' },
      },
      level => 8,
   };
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Notitia::Schema::Schedule::Result::Job - People and resource scheduling

=head1 Synopsis

   use App::Notitia::Schema::Schedule::Result::Job;
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
