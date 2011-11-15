package WWW::Wikipedia::List;
use strict;
use warnings;
our $VERSION = '0.01';
use utf8;
use Encode;
use Lingua::JA::Moji qw/kana2romaji/;
use Carp qw/croak/;
use URI;
use XML::Simple;
use Coro;
use FurlX::Coro;

use constant WIKIPEDIA_URL => 'http://ja.wikipedia.org/wiki/%s';
use constant WIKIPEDIA_XML => sprintf(WIKIPEDIA_URL, '特別:データ書き出し/%s');

sub new {
    my ($class, $opt) = @_;

    my $cache = Cache::FileCache->new($opt || {
        cache_root         => '/tmp',
        namespace          => 'WWW-Wikipedia-List',
        default_expires_in => '7d',
    });
    my $ua = FurlX::Coro->new(agent => 'Mozilla/5.0');

    bless { cache => $cache, ua => $ua }, $class;
}

sub get {
    my ($self, $str) = @_;

    croak "get() requires you pass in a string" unless $str;

    my $ret;
    unless ( $ret = $self->{cache}->get(encode_utf8($str)) ) {
        my $src = URI->new(sprintf(WIKIPEDIA_XML, $str));
        my $res = $self->{ua}->get($src);
        die $res->status_line unless $res->is_success;
        my $content = XMLin($res->content)->{page}{revision}{text}{content};

        my $re_index = qr/\[\[$str\s*(.+)行\]\]/;
        if ( $content =~ $re_index ) {
            my @coros;
            foreach my $line ( split(/\n/, $content) ) {
                if ( $line =~ $re_index ) {
                    my $index = $1;
                    push @coros, async {
                        $src = URI->new(sprintf(WIKIPEDIA_XML, $str . '_' . $index . '行'));
                        $res = $self->{ua}->get($src);
                        die $res->status_line unless $res->is_success;
                        my $new_content = XMLin($res->content)->{page}{revision}{text}{content};

                        return _parse_pornstars->($new_content, $index) if $str eq 'AV女優一覧';
                        return _parse->($new_content, $index);
                    };
                }
            }
            my @list;
            foreach my $coro (@coros) {
                my $arrayref = $coro->join;
                next unless $arrayref;
                push @list, @{ $arrayref };
            }
            $ret = \@list;
        }
        else {
            $ret = _parse->($content);
        }

        $self->{cache}->set(encode_utf8($str), $ret);
        $self->{list} = $ret;
    }

    return wantarray ? @{ $ret } : $ret;
}

sub index {
    my ($self, $index) = @_;
    my @list = grep { $_->{index} eq $index } @{ $self->{list} };
    return \@list;
}

sub _parse {
    my ($content, $index) = @_;

    my @list;
    foreach my $line ( split(/\n/, $content) ) {
        last if $line =~ /==\s*関連項目\s*==/;

        if ( $line =~ /==\s*([あ-ん]{1})行\s*==/ ) {
            $index = $1;
        }
        elsif ( $line =~ /\*\s*\[\[([^\[\]]+)\]\]/ ) {
            my $entry;
            $entry->{title} = $1;
            $entry->{title} =~ s/.*\|//;
            $entry->{index} = $index || '';
            $entry->{url}   = sprintf(WIKIPEDIA_URL, $entry->{title});
            $entry->{xml}   = sprintf(WIKIPEDIA_XML, $entry->{title});
            push @list, $entry;
        }
    }

    return \@list;
}

sub _parse_pornstars {
    my ($content, $index) = @_;

    my @pornstars;
    foreach my $line ( split(/\n/, $content) ) {
        next unless $line =~ /^\*\s\[\[/;

        if ( $line =~ /\[\[([^\[\]]+)\]\][（(]([^()（）]+)[)）](.*)/ ) {
            my ($entry, $tmp) = ({ name => $1, yomi => $2 }, $3);
            $entry->{name} =~ s/.*\|//;
            $entry->{engname} = kana2romaji(
                $entry->{yomi},
                { style => 'passport', ve_type => 'none' }
            );
            $entry->{year} =
                $tmp =~ /[（(](?:\[\[)?(\d{4})\s*年(?:\]\])?[)）]/ ? $1 : '';
            $entry->{index} = $index;
            push @pornstars, $entry;
        }
    }

    return \@pornstars;
}

1;
__END__

=head1 NAME

WWW::Wikipedia::List -

=head1 SYNOPSIS

  use WWW::Wikipedia::List;
  use utf8;
  my $wiki = WWW::Wikipedia::List->new();

  my @drama = $wiki->get('日本のテレビドラマ一覧');
  my @anime = $wiki->get('日本のテレビアニメ作品一覧');
  my @movie_youga = $wiki->get('映画作品一覧');
  my @movie_houga = $wiki->get('日本の映画作品一覧');
  my @movie_anime = $wiki->get('日本のアニメ映画作品一覧');
  my @pornstars = $wiki->get('AV女優一覧');

  foreach my $entry (@drama) {
      print $entry->{index} . "\n";
      print $entry->{title} . "\n";
      print $entry->{url} . "\n";
      print $entry->{xml} . "\n";
  }

=head1 DESCRIPTION

WWW::Wikipedia::List is

=head1 AUTHOR

Wataru Nagasawa E<lt>nagasawa {at} junkapp.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
