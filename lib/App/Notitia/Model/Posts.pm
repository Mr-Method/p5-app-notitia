package App::Notitia::Model::Posts;

use App::Notitia::Attributes;  # Will do cleaning
use App::Notitia::Util     qw( add_dummies build_tree iterator localise_tree
                               mtime register_action_paths
                               set_last_modified_header );
use Class::Usul::Constants qw( SPC TRUE );
use Class::Usul::Types     qw( NonZeroPositiveInt PositiveInt );
use English                qw( -no_match_vars );
use Moo;

extends q(App::Notitia::Model);

has '+moniker' => default => 'posts';

has 'depth_offset' => is => 'ro', isa => PositiveInt, default => 3;

has 'max_navigation' => is => 'ro', isa => NonZeroPositiveInt, default => 1000;

with q(App::Notitia::Role::PageConfiguration);
with q(App::Notitia::Role::Navigation);
with q(App::Notitia::Role::PageLoading);
with q(App::Notitia::Role::WebAuthorisation);
with q(App::Notitia::Role::Editor);
with q(App::Notitia::Role::RSS);

register_action_paths
   'posts/dialog' => 'posts/dialog',
   'posts/page' => 'posts',
   'posts/rss_feed' => 'posts/rss';

# Construction
around 'get_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash = $orig->( $self, $req, @args ); add_dummies $stash;

   $stash->{page}->{location} = 'events';
   $stash->{navigation} = $self->events_navigation_links( $req, $stash->{page});

   return $stash;
};

around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page  = $orig->( $self, $req, @args );
   my @ids   = @{ $req->uri_params->() // [] };
   my $type  = $page->{type} // 'folder';
   my $skin  = $req->session->skin || $self->config->skin;
   my $plate = $type eq 'folder' ? 'posts-index' : 'documentation';

   $page->{has_rss_feed} = TRUE;

   $ids[ 0 ] and $ids[ 0 ] eq 'index' and @ids = ();
   $page->{wanted_depth} = () = @ids;
   $page->{wanted      } = join '/', $self->config->posts, @ids;

   defined $page->{template}->[ 1 ]
        or $page->{template}->[ 1 ] = "${skin}/${plate}";

   return $page;
};

# Private package variables
my $_posts_cache = { _mtime => 0, };

# Private methods
my $_chain_nodes = sub {
   my ($self, $tree) = @_; my $iter = iterator $tree; my $prev;

   while (defined (my $node = $iter->())) {
      ($node->{type} eq 'folder' or $node->{id} eq 'index') and next;
      $prev and $prev->{next} = $node; $node->{prev} = $prev; $prev = $node;
   }

   return;
};

# Public methods
sub base_uri {
   return $_[ 1 ]->uri_for_action( 'posts/page', $_[ 2 ] );
}

sub cancel_edit_action : Role(anon) {
   return $_[ 0 ]->page( $_[ 1 ], { cancel_edit => TRUE } );
}

sub create_file_action : Role(editor) Role(event_manager) {
   return $_[ 0 ]->create_file( $_[ 1 ], { prefix => $_[ 0 ]->config->posts } );
}

sub delete_file_action : Role(editor) Role(event_manager) {
   my ($self, $req) = @_; my $stash = $self->delete_file( $req );

   $stash->{redirect}->{location} = $req->uri_for_action( 'posts/page' );

   return $stash;
}

sub dialog : Dialog Role(any) {
   return $_[ 0 ]->get_dialog( $_[ 1 ] );
}

sub localised_posts_dir {
   my ($self, $locale, $opts) = @_; my $conf = $self->config; $opts //= {};

   return $conf->docs_root->catdir( $locale, $conf->posts, $opts );
}

sub localised_tree {
   return localise_tree $_[ 0 ]->tree_root( $_[ 1 ] ), $_[ 2 ];
}

sub nav_label {
   return sub { my ($req, $link) = @_; $link->{prefix}.SPC.$link->{title} };
}

sub page : Role(anon) {
   my ($self, $req, $page) = @_;

   my $stash = $self->get_stash( $req, $page );

   set_last_modified_header $stash, $stash->{page}->{modified};

   return $stash;
}

sub qualify_path {
   my ($self, $locale, @pathname) = @_;

   my $opts = pop @pathname; my $conf = $self->config;

   if ($opts->{draft}) { shift @pathname; unshift @pathname, $conf->drafts }

   unshift @pathname, $conf->posts;

   return $self->config->docs_root->catfile( $locale, @pathname )->utf8;
}

sub rename_file_action : Role(editor) Role(event_manager) {
   return $_[ 0 ]->rename_file( $_[ 1 ], { prefix => $_[ 0 ]->config->posts } );
}

sub rss_feed : Role(anon) {
   return $_[ 0 ]->get_rss_feed( $_[ 1 ] );
}

sub save_file_action : Role(editor) Role(event_manager) {
   return $_[ 0 ]->save_file( $_[ 1 ] );
}

sub tree_root {
   my ($self, $req) = @_; my $mtime = $self->docs_mtime_cache( $req );

   if ($mtime == 0 or $mtime > $_posts_cache->{_mtime}) {
      my $conf      = $self->config;
      my $postd     = $conf->posts;
      my $no_index  = join '|', grep { not m{ $postd }mx } @{ $conf->no_index };
      my $max_mtime = $_posts_cache->{_mtime};

      for my $locale (@{ $conf->locales }) {
         my $lcache = $_posts_cache->{ $locale } //= {};
         my $dir    = $self->localised_posts_dir( $locale, { reverse => TRUE } )
                           ->filter( sub { not m{ (?: $no_index ) }mx } );

         $dir->exists or next;
         $self->log->info( "Tree building ${dir} ${PID}" );
         $lcache->{tree} = build_tree( $self->type_map, $dir, 2 );
         $lcache->{type} = 'folder';
         $self->$_chain_nodes( $lcache );

         my $mtime = mtime $lcache; $mtime > $max_mtime and $max_mtime = $mtime;
      }

      if ($max_mtime > $mtime) { $self->docs_mtime_cache( $req, $max_mtime ) }
      else { $_posts_cache->{_mtime} = $mtime }
   }

   return $_posts_cache;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Notitia::Model::Posts - People and resource scheduling

=head1 Synopsis

   use App::Notitia::Model::Posts;
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
