package App::Notitia::Plugin::UKHolidays;

use namespace::autoclean;

use App::Notitia::Constants qw( FALSE TRUE );
use Moo;

with q(Web::Components::Role);

# Public attributes
has '+moniker' => default => 'holidays';

# Private functions
my $_skip_weekend = sub {
   my $dt = shift; my $dow = $dt->day_of_week;

   return $dow > 5 ? $dt->clone->add( days => 8 - $dow ) : $dt->clone;
};

my $_christmas_day = sub {
   return $_skip_weekend->( $_[ 0 ]->clone->set( month => 12, day => 25 ) );
};

my $_boxing_day = sub {
   my $dt = shift;

   $dt = $_skip_weekend->( $dt->clone->set( month => 12, day => 26 ) );

   $_christmas_day->( $dt )->day_of_week == 1 and $dt->day_of_week == 1
      and $dt->add( days => 1 );

   return $dt;
};

my $_new_year = sub {
   return $_skip_weekend->( $_[ 0 ]->clone->set( month => 1, day => 1 ) );
};

my $_may_day = sub {
   my $dt = shift;

   # 1995 moved for 50th anniversary of VE day
   $dt->year == 1995 and return $dt->clone->set( month => 5, day => 8 );

   return $_skip_weekend->( $dt->clone->set( month => 5, day => 1 ) );
};

my $_prev_monday = sub {
   my $dt = shift; my $dow = $dt->day_of_week;

   return $dow > 1 ? $dt->clone->subtract( days => ($dow - 1) ) : $dt->clone;
};

my $_spring = sub {
   my $dt = shift;

   # Golden Jubilee
   $dt->year == 2002 and return $dt->clone->set( month => 6, day => 4 );
   # Diamond Jubilee
   $dt->year == 2012 and return $dt->clone->set( month => 6, day => 4 );

   return $_prev_monday->( $dt->clone->set( month => 5, day => 31 ) );
};

my $_summer = sub {
   return $_skip_weekend->( $_[ 0 ]->clone->set( month => 8, day => 25 ) );
};

my $_easter = sub {
   my $dt    = shift;
   # This id Oudin's algorithm
   # See http://www.gmarts.org/index.php?go=415
   my $year  = $dt->year;
   my $g     = $year % 19;
   my $c     = $year / 100;
   my $h     = ($c - $c / 4 - (8 * $c + 13) / 25 + 19 * $g + 15) % 30;
   my $i     = $h - ($h / 28) * (1 - ($h / 28) * (29 / ($h + 1)) * ((21 - $g) / 11));
   my $j     = ($year + $year / 4 + $i + 2 - $c + $c / 4) % 7;
   my $p     = $i - $j;
   my $day   = int(($p + 27 + ($p + 6) / 40) % 31);
   my $month = int(3 + ($p + 26) / 30);

   return $dt->clone->set( month => $month, day => $day );
};

my $_good_friday = sub {
   my $dt = $_easter->( $_[ 0 ] ); $dt->subtract( days => 2 ); return $dt;
};

my $_easter_monday = sub {
   my $dt = $_easter->( $_[ 0 ] ); $dt->add( days => 1 ); return $dt;
};

my $_holiday_cache = {};

my $_bank_holidays = sub {
   my $dt = shift; my $year = $dt->year; my @holidays;

   exists $_holiday_cache->{ $year } and return $_holiday_cache->{ $year };

   push @holidays, $_new_year->( $dt ) if $year > 1973;
   push @holidays, $_good_friday->( $dt );
   push @holidays, $_easter_monday->($dt );
   push @holidays, $_may_day->( $dt ) if $year > 1977;
   push @holidays, $_spring->( $dt );

   # Weddings, Jubilees etc
   push @holidays, $dt->clone->set( month => 6, day => 3 )  if $year == 2002;
   push @holidays, $dt->clone->set( month => 4, day => 29 ) if $year == 2011;
   push @holidays, $dt->clone->set( month => 6, day => 5 )  if $year == 2012;

   push @holidays, $_summer->( $dt );
   push @holidays, $_christmas_day->( $dt );
   push @holidays, $_boxing_day->( $dt );

   return $_holiday_cache->{ $year } = \@holidays;
};

# Public methods
sub is_bank_holiday {
   my ($self, $dt) = @_;

   for my $holiday (@{ $_bank_holidays->( $dt ) }) {
      $dt == $holiday and return TRUE;
   }

   return FALSE;
}

sub is_working_day {
   my ($self, $dt) = @_;

   return $dt->day_of_week > 5 || $self->is_bank_holiday( $dt ) ? FALSE : TRUE;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Notitia::Plugin::UKHolidays - People and resource scheduling

=head1 Synopsis

   use App::Notitia::Plugin::UKHolidays;
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

John Sargent, C<< <john@j-bg.co.uk> >>

=head1 License and Copyright

Copyright (c) 2016 John Sargent. All rights reserved

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
