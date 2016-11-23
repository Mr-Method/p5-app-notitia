package App::Notitia::Attributes;

use strictures;
use attributes ();
use namespace::autoclean ();
use parent 'Exporter::Tiny';

use App::Notitia::Constants qw( FALSE TRUE );

our @EXPORT = qw( FETCH_CODE_ATTRIBUTES MODIFY_CODE_ATTRIBUTES );

our @EXPORT_OK = qw( is_action is_dialog );

# Private
my $Code_Attr = {};

my $_attr_for = sub {
   my ($components, $actionp) = @_;

   $components //= {}; $actionp or return FALSE;

   my ($moniker, $method) = split m{ / }mx, $actionp;
   my $component = $components->{ $moniker } or return FALSE;
   my $code_ref = $component->can( $method ) or return FALSE;

   return attributes::get( $code_ref ) // {};
};

# Public
sub import {
   my $class   = shift;
   my $caller  = caller;
   my $globals = { $_[ 0 ] && ref $_[ 0 ] eq 'HASH' ? %{+ shift } : () };
   my @wanted  = (qw( FETCH_CODE_ATTRIBUTES MODIFY_CODE_ATTRIBUTES ), @_);

   namespace::autoclean->import( -cleanee => $caller, -except => [ @EXPORT ] );
   $globals->{into} //= $caller; $class->SUPER::import( $globals, @wanted );
   return;
}

sub is_action ($$) {
   return $_attr_for->( $_[ 0 ], $_[ 1 ] )->{Action} ? TRUE : FALSE;
}

sub is_dialog ($$) {
   return $_attr_for->( $_[ 0 ], $_[ 1 ] )->{Dialog} ? TRUE : FALSE;
}

sub FETCH_CODE_ATTRIBUTES {
   my ($class, $code) = @_; return $Code_Attr->{ 0 + $code } // {};
}

sub MODIFY_CODE_ATTRIBUTES {
   my ($class, $code, @attrs) = @_;

   for my $attr (@attrs) {
      my ($k, $v) = $attr =~ m{ \A ([^\(]+) (?: [\(] ([^\)]+) [\)] )? \z }mx;

      my $vals = $Code_Attr->{ 0 + $code }->{ $k } //= []; defined $v or next;

         $v =~ s{ \A \` (.*) \` \z }{$1}msx
      or $v =~ s{ \A \" (.*) \" \z }{$1}msx
      or $v =~ s{ \A \' (.*) \' \z }{$1}msx; push @{ $vals }, $v;

      $Code_Attr->{ 0 + $code }->{ $k } = $vals;
   }

   return ();
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Notitia::Attributes - People and resource scheduling

=head1 Synopsis

   use App::Notitia::Attributes;
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
