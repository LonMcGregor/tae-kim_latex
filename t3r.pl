#!/usr/bin/perl
# Copyright (C) 2010-2012 Philipp Kerling
# Copyright (C) 2020 Léon McGregor
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use feature qw/say switch/;
use utf8;

use HTML::TreeBuilder;
use HTML::Entities;
use URI;
use GD;
use Carp;

binmode STDOUT, ':utf8';

$| = 1; # ‽

# Walk thru TOC, process book
my $toc = get_contents();

# these vars need to be outisde the walk_toc sub, as recursion happens within
my $sectioncount;
my $chaptercount = 2; # start at 2 as there are 2 pre-defined front matter chapters
my $nextchapterstartssection = 0;
walk_toc($toc);

sub get_contents {
	# return the $node of the table of contents
	my $tree = new HTML::TreeBuilder;
	my $fh;
	my $contentstext;
	# don't bother trying to get the whole TOC, just read it from a file.
	open($fh, "<:encoding(UTF-8)", "examplecontents.html") or die "Opening toc Failed";
	read($fh, $contentstext, -s $fh);
	$tree->parse_content($contentstext);
	my $node = $tree->look_down("_tag", "h2", sub { $_[0]->as_text() eq 'Content' } )->right;
	return $node;
}

sub walk_toc {
	# Process the book according to the table of contents order given in $node
	my ($tree) = @_;
	my @nodes = $tree->content_list();
	open(MANIFEST, ">>:encoding(UTF-8)", "manifest.txt") or die "Opening manifest Failed";
	open(SPINE, ">>:encoding(UTF-8)", "spine.txt") or die "Opening spine Failed";
	open(NAVMAP, ">>:encoding(UTF-8)", "navmap.txt") or die "Opening nav Failed";
	foreach my $node (@nodes) {
		my $nodeclass = $node->attr("class");
		if ($nodeclass and $nodeclass eq "sym"){
			# if we've walked into a fancy styling bit with no info, back out
			return;
		}
		my $tag = $node->tag;
		if (elem_in_list($tag, ['li', 'div', 'span', 'ol'])) {
			walk_toc($node);
		} elsif ($tag eq 'ul') {
			$sectioncount++;
			$nextchapterstartssection = 1;
			walk_toc($node);
		} elsif ($tag eq 'a') {
			$chaptercount++;
			my $text = $node->as_text();
			if($nextchapterstartssection == 1){
				$text = "Section $sectioncount: " . $text;
				$nextchapterstartssection = 0;
			}
			my $url = $node->attr("href");
			my $identifier = $1 if ($url =~ m@/([^/]+?)/?$@);
			say "+ $text @ raw_html/$identifier.html -> epub_pages/OEBPS/$identifier.xhtml";
			# write the table of contents files
			say MANIFEST "        <item id=\"$identifier\" href=\"OEBPS/$identifier.xhtml\" media-type=\"application/xhtml+xml\" />";
			say SPINE "        <itemref idref=\"$identifier\" />";
			say NAVMAP "        <navPoint id=\"$identifier\" playOrder=\"$chaptercount\">";
			say NAVMAP "            <navLabel>";
			say NAVMAP "                <text>$text</text>";
			say NAVMAP "            </navLabel>";
			say NAVMAP "            <content src=\"OEBPS/$identifier.xhtml\"/>";
			say NAVMAP "        </navPoint>";
			# process the chapter text
			process_chapter($identifier, $text);
		} else {
			carp "Unknown TOC tag $tag";
		}
	}
	close(MANIFEST);
	close(SPINE);
	close(NAVMAP);
}

sub elem_in_list {
	# Check if $element is included in $list
	my ($e, $l) = @_;
	return ($e eq $l) unless (ref $l);
	foreach my $i (@$l) { return 1 if ($i eq $e); }
	return 0;
}

sub del_tags_from_article {
	my ($article, $tag, $identifier) = @_;
	my @s1 = $article->find( "_tag", $tag );
	if(scalar @s1 == 0){
		# say "No $tag in $identifier";
	} else {
		foreach(@s1){
			$_->delete();
		}
	}
}
sub del_id_from_article {
	my ($article, $id, $identifier) = @_;
	my $s1 = $article->look_down( "id", $id );
	if($s1){
		$s1->delete();
	} else {
		# say "No $id in $identifier";
	}
}
sub del_class_from_article {
	my ($article, $class, $identifier) = @_;
	my $s1 = $article->look_down( "class", $class );
	if($s1){
		$s1->delete();
	} else {
		# say "No $class in $identifier";
	}
}

sub replace_web_resources {
	# replace every instance of a web source
	my ($tree, $tag) = @_;
	my @allchildren = $tree->find($tag);
	foreach(@allchildren){
		my $url = $_->attr('src');
		my $replacement = HTML::Element->new('a', 'href' => $url);
		$replacement->push_content("Web Resource: " . encode_entities($url));
		$_->replace_with($replacement);
	}
}

sub process_chapter {
	my ($identifier, $title) = @_;

	# read cached html
	open(my $htmlfile, '<:encoding(UTF-8)', "raw_html/$identifier.html") or die "Opening $identifier Failed";
	read($htmlfile, my $htmlcontent, -s $htmlfile);
	close $htmlfile;

	#clean up html
	# hiragana, katakana and kanji pages have this in the middle of the content, HTML::TreeBuilder freaks out then
	$htmlcontent =~ s#<link .*?/>##g;
	my $tree = new HTML::TreeBuilder;
	$tree->parse_content($htmlcontent);
	my $articlecontent = $tree->look_down( "_tag", "div", "class", "entry-content" );
	del_tags_from_article($articlecontent, "script", $identifier);
	del_tags_from_article($articlecontent, "noscript", $identifier);
	del_tags_from_article($articlecontent, "fieldset", $identifier);
	del_id_from_article($articlecontent, "toc_container", $identifier);
	del_class_from_article($articlecontent, "sharedaddy sd-sharing-enabled", $identifier);
	replace_web_resources($articlecontent, 'iframe');
	my $encoded_title = encode_entities($title);

	# write file
	open(my $articlefile, '>>:encoding(UTF-8)', "epub_pages/OEBPS/$identifier.xhtml") or die;
	say $articlefile "<?xml version='1.0' encoding='utf-8'?>";
	say $articlefile '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"';
	say $articlefile '"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">';
	say $articlefile '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">';
	say $articlefile '<head>';
	say $articlefile "<title>$title</title>";
	say $articlefile '<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>';
	say $articlefile '</head>';
	say $articlefile '<body>';
	say $articlefile "<h1>$encoded_title</h1>";
	say $articlefile $articlecontent->as_HTML('',"\t",{});
	say $articlefile '</body></html>';
	close $articlefile;
}
