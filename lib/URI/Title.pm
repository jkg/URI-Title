=head1 NAME

URI::Title - get the titles of things on the web in a sensible way

=head1 SYNOPSIS

  use URI::Title qw( title );
  my $title = title('http://microsoft.com');
  print "Title is $title\n";

=head1 DESCRIPTION

I keep having to find the title of things on the web. This seems like a really
simple request, just get() the object, parse for a title tag, you're done. Ha,
I wish. There are several problems with this approach:

=over 4

=item What if the resource is on a very slow server? Do we wait for ever or what?

=item What if the resource is a 900 gig file? You don't want to download that.

=item What if the page title isn't in a title tag, but is buried in the HTML somewhere?

=item What if the resource is an MP3 file, or a word document or something?

=item ...

=back

So, let's solve these issues once.

=head1 METHODS

only one, the title(url) method. Call it with an url, get the title if possible,
undef if it wasn't. Very simple.

=head1 TODO

Many, many, many things. Still unimplemented:

=over 4

=item Get titles of MP3 files, Word Docs, PDFs, etc.

=item Configurable.. well, anything, in fact. Timeout would be a good start.

=item Better error reporting.

=head1 CREDITS

Invented because of a conversation with rjp, who contributed some eyeball-melting and
as-yet-unused code to get titles from MP3s and PDFs, and hex, who has also solved the
problem, and got bits done in a nicer way than I did.

=cut

package URI::Title;

use base qw(Exporter);
our @EXPORT_OK = qw( title );

our $VERSION = '0.3';

use Module::Pluggable (search_path => ['URI::Title'], require => 1 );
use File::Type;

use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;

sub get_limited {
  my $url = shift;
  my $size = shift || 8*1024;
  my $ua = LWP::UserAgent->new;
  $ua->timeout(20);
  $ua->max_size($size);
  my $req = HTTP::Request->new(GET => $url);
  $req->header( Range => "bytes=0-$size" );
  my $res = $ua->request($req);
  return unless $res->is_success;
  return $res->content;
}

sub get_all {
  my $url = shift;
  my $ua = LWP::UserAgent->new;
  $ua->timeout(20);
  my $req = HTTP::Request->new(GET => $url);
  my $res = $ua->request($req);
  return unless $res->is_success;
  return $res->content;
}

sub handlers {
  my @plugins = plugins();
  my %handlers;
  for my $plugin (@plugins) {
    for my $type ($plugin->types) {
      $handlers{$type} = $plugin;
    }
  }
  return \%handlers;
}

sub title {
  my $param = shift;
  my $data;
  my $url;

  if (ref($param)) {
    if ($param->{data}) {
      $data = $param->{data};
    } elsif ($param->{url}) {
      $url = $param->{url};
      $data = get_limited($url);
    } else {
      use Carp qw(croak);
      croak("Expected a single parameter, or an 'url' or 'data' key");
    }
  } else {
    # url
    $url = $param;
    $data = get_limited($url);
  }

  return undef unless $data;

  my $type = File::Type->new->checktype_contents($data);
  warn "type is $type\n";

  my $handlers = handlers();
  my $handler = $handlers->{$type} || $handlers->{default}
    or return;

  return $handler->title($url, $data, $type);
}

1;

