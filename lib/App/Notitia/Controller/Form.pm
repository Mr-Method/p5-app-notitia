package App::Notitia::Controller::Form;

use Web::Simple;

with q(Web::Components::Role);

has '+moniker' => default => 'form';

sub dispatch_request {
   sub (POST + /form-defn/*/field/*   + ?*) {[ 'form/from_request',       @_ ]},
   sub (POST + /form-defn/*/field     + ?*) {[ 'form/from_request',       @_ ]},
   sub (GET  + /form-defn/*/field/*   + ?*) {[ 'form/field_defn_view',    @_ ]},
   sub (GET  + /form-defn/*/field     + ?*) {[ 'form/field_defn_view',    @_ ]},
   sub (GET  + /form-defn/*/preview   + ?*) {[ 'form/form_defn_preview',  @_ ]},
   sub (POST + /form-defn/*           + ?*) {[ 'form/from_request',       @_ ]},
   sub (POST + /form-defn             + ?*) {[ 'form/from_request',       @_ ]},
   sub (GET  + /form-defn/*           + ?*) {[ 'form/form_defn_view',     @_ ]},
   sub (GET  + /form-defn             + ?*) {[ 'form/form_defn_view',     @_ ]},
   sub (GET  + /form-defns            + ?*) {[ 'form/form_defn_list',     @_ ]},
   sub (GET  + /form/*                + ?*) {[ 'manage/form_view',        @_ ]},
   sub (GET  + /forms                 + ?*) {[ 'manage/form_list',        @_ ]},
   sub (POST + /table/*/column/*      + ?*) {[ 'table/from_request',      @_ ]},
   sub (POST + /table/*/column        + ?*) {[ 'table/from_request',      @_ ]},
   sub (GET  + /table/*/column/*      + ?*) {[ 'table/column_view',       @_ ]},
   sub (GET  + /table/*/column        + ?*) {[ 'table/column_view',       @_ ]},
   sub (POST + /table/* | /table      + ?*) {[ 'table/from_request',      @_ ]},
   sub (GET  + /table/* | /table      + ?*) {[ 'table/table_view',        @_ ]},
   sub (GET  + /tables                + ?*) {[ 'table/table_list',        @_ ]};
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Notitia::Controller::Form - People and resource scheduling

=head1 Synopsis

   use App::Notitia::Controller::Form;
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
