package Font::Scripts::GDL;

use Font::TTF::Font;
use Font::Scripts::AP;
use Unicode::Normalize;

use strict;
use vars qw($VERSION @ISA);
@ISA = qw(Font::Scripts::AP);

$VERSION = "0.03";  # MJPH   9-AUG-2005     Support glyph alternates naming (A/u0410), normalization
# $VERSION = "0.02";  # MJPH  26-APR-2004     Add to Font::Scripts::AP hierarchy
# $VERSION = "0.01";  # MJPH   8-OCT-2002     Original based on existing code

*read_font = \&Font::Scripts::AP::read_font;

sub start_gdl
{
    my ($self, $fh) = @_;
    my ($fname) = $self->{'font'}{'name'}->find_name(4);

    $fh->print("/*\n    Glyph information for font $fname at " . localtime() . "\n*/\n\n");
    $fh->print("table(glyph) {MUnits = $self->{'font'}{'head'}{'unitsPerEm'}};\n");
    $self;
}

sub out_gdl
{
    my ($self, $fh) = @_;
    my ($f) = $self->{'font'};
    my (%lists, %glyph_names);
    my ($i, $sep, $p, $k, $glyph);

    for ($i = 0; $i < $f->{'maxp'}{'numGlyphs'}; $i++)
    {
        $glyph = $self->{'glyphs'}[$i];
        $fh->print("$glyph->{'name'} = ");
        $fh->print("glyphid($i)");

        $sep = ' {';
        foreach $p (keys %{$glyph->{'points'}})
        {
            my ($pname) = $p;
            my ($pt) = $glyph->{'points'}{$p};

            $pname .= 'S' unless ($pname =~ s/^_(.*)/${1}M/o);
            $fh->print("$sep$pname = ");
            if (defined $pt->{'cont'})
            { $fh->print("gpath($pt->{'cont'})"); }
            else
            { $fh->print("point($pt->{'x'}m, $pt->{'y'}m)"); }
            $sep = '; ';
        }
        foreach $k (keys %{$glyph->{'comps'}})
        {
            $fh->print("${sep}component.$k = box(" . join(", ", map {"${_}m"} @{$glyph->{'comps'}{$k}}) . ")");
            $sep = '; ';
        }
        foreach $k (keys %{$glyph->{'props'}})
        {
            my ($n) = $k;
            next unless ($n =~ s/^GDL(?:_)?//o);
            $fh->print("$sep$n=$glyph->{'props'}{$k}");
            $sep = '; ';
        }
        $fh->print("}") if ($sep ne ' {');
        $fh->print(";\n");
    }
}

sub out_classes
{
    my ($self, $fh) = @_;
    my ($f) = $self->{'font'};
    my ($lists) = $self->{'lists'};
    my ($classes) = $self->{'classes'};
    my ($ligclasses) = $self->{'ligclasses'};
    my ($vecs) = $self->{'vecs'};
    my ($glyphs) = $self->{'glyphs'};
    my ($l, $name, $count, $sep, $psname, $cl, $i, $c);

    $fh->print("\n/* Classes */\n");

    foreach $l (sort keys %{$lists})
    {
        my ($name) = $l;

        if ($name !~ m/^_/o)
        { $name = "Takes$name"; }
        else
        { $name =~ s/^_//o; }

        $fh->print("c${name}Dia = (");
        $count = 0; $sep = '';
        foreach $cl (@{$lists->{$l}})
        {
    #        next if ($l eq 'LS' && $cl =~ m/g101b.*_med/o);      # special since no - op in GDL
            $fh->print("$sep$glyphs->[$cl]{'name'}");
            if (++$count % 8 == 0)
            { $sep = ",\n    "; }
            else
            { $sep = ", "; }
        }
        $fh->print(");\n\n");

        next unless defined $vecs->{$l};

        $fh->print("cn${name}Dia = (");
        $count = 0; $sep = '';
        for ($c = 0; $c < $f->{'maxp'}{'numGlyphs'}; $c++)
        {
            $psname = $f->{'post'}{'VAL'}[$c];
            next if ($psname eq '' || $psname eq '.notdef');
            next if (vec($vecs->{$l}, $c, 1));
            next if (defined $glyphs->[$c]{'props'}{'GDL_order'} && $glyphs->[$c]{'props'}{'GDL_order'} <= 1);
            $fh->print("$sep$glyphs->[$c]{'name'}");
            if (++$count % 8 == 0)
            { $sep = ",\n    "; }
            else
            { $sep = ", "; }
        }
        $fh->print(");\n\n");
    }


    foreach $cl (sort keys %{$classes})
    {
        $fh->print("c$cl = ($glyphs->[$classes->{$cl}[0]]{'name'}");
        for ($i = 1; $i <= $#{$classes->{$cl}}; $i++)
        { $fh->print($i % 8 ? ", $glyphs->[$classes->{$cl}[$i]]{'name'}" : ",\n    $glyphs->[$classes->{$cl}[$i]]{'name'}"); }
        $fh->print(");\n\n");
    }

    foreach $cl (sort keys %{$ligclasses})
    {
        $fh->print("cl$cl = ($glyphs->[$ligclasses->{$cl}[0]]{'name'}");
        for ($i = 1; $i <= $#{$ligclasses->{$cl}}; $i++)
        { $fh->print($i % 8 ? ", $glyphs->[$ligclasses->{$cl}[$i]]{'name'}" : ",\n    $glyphs->[$ligclasses->{$cl}[$i]]{'name'}"); }
        $fh->print(");\n\n");
    }

    $self;
}

sub endtable
{
    my ($self, $fh) = @_;

    $fh->print("endtable;\n");
}


sub end_gdl
{
    my ($self, $fh, $include) = @_;

    $fh->print("\n#define MAXGLYPH " . ($self->{'font'}{'maxp'}{'numGlyphs'} - 1) . "\n");
    $fh->print("\n#include \"$include\"\n") if ($include);
}

sub make_name
{
    my ($self, $gname, $uni, $glyph) = @_;
    $gname =~ s{/.*$}{}o;
    $gname =~ s/\.(.)/'_'.lc($1)/oge;
    if ($gname =~ m/^u(?:ni)?(?:[0-9A-Fa-f]{4,6})/o)
    { 
        $gname = "g" . lc($gname);
        $gname =~ s/^gu(?:ni)?/g/o;
        $gname =~ s/_u/_/og;
    }
    else
    {
        $gname = "g_" . $gname;
        $gname =~ s/([A-Z])/"_".lc($1)/oge;
    }
    $gname;
}

sub make_point
{
    my ($self, $p, $glyph) = @_;

    if ($p =~ m/^%([a-z0-9]+)_([a-z0-9]+)$/oi)
    {
        my ($left, $right) = ($1, $2);
        my ($top) = $self->{'font'}{'head'}{'ascent'};
        my ($bot) = $self->{'font'}{'head'}{'descent'};
        my ($adv) = $self->{'font'}{'hmtx'}->read->{'advances'}[$glyph->{'gnum'}];
        my ($split) = $glyph->{'points'}{$p}{'x'};

        $glyph->{'comps'}{$left} = [0, $bot, $split, $top];
        $glyph->{'comps'}{$right} = [$split, $bot, $adv, $top];
        return undef;
    }

    return $p;
}

sub normal_rules
{
    my ($self, $fh, $pnum) = @_;
    my ($g, $struni, $seq, $dseq, $dcomb, @decomp, $d);
    my ($c) = $self->{'cmap'};
    my ($glyphs) = $self->{'glyphs'};

    $fh->print("\ntable(substitution);\npass($pnum);\n");
    foreach $g (@{$self->{'glyphs'}})
    {
        next unless ($g->{'props'}{'drawn'});
        next unless ($c->{$g->{'uni'}} == $g->{'gnum'});
        $struni = pack('U', $g->{'uni'});
        $seq = NFD($struni);
        next if ($seq eq $struni);
        @decomp = unpack('U*', $seq);
        my ($dok) = 1;
        foreach $d (@decomp)
        { $dok = 0 unless $c->{$d}; }
        next unless $dok;

        $fh->print(join(' ', map {$glyphs->[$c->{$_}]{'name'}} @decomp) . " > $g->{'name'} " . ("_ " x (scalar @decomp - 1)) . ";\n");

        if (scalar @decomp > 2)
        {
            $fh->print(join(' ', map {$glyphs->[$c->{$_}]{'name'}} @decomp[0, 2, 1]) . " > $g->{'name'} _ _;\n");
            $dseq = pack('U*', @decomp[0, 1]);
            $dcomb = NFC($dseq);
            if ($dcomb ne $dseq)
            { $fh->print($glyphs->[$c->{unpack('U', $dcomb)}]{'name'} . " " . $glyphs->[$c->{$decomp[2]}]{'name'} . " > $g->{'name'} _;\n"); }

            $dseq = pack('U*', @decomp[0, 2]);
            $dcomb = NFC($dseq);
            if ($dcomb ne $dseq)
            { $fh->print($glyphs->[$c->{unpack('U', $dcomb)}]{'name'} . " " . $glyphs->[$c->{$decomp[1]}]{'name'} . " > $g->{'name'} _;\n"); }
        }
    }
    $fh->print("endpass;\nendtable;\n");
}

sub lig_rules
{
    my ($self, $fh, $pnum, $type) = @_;
    my ($ligclasses) = $self->{'ligclasses'};
    my ($c);

    return unless (scalar %{$self->{'ligclasses'}});
    $fh->print("\ntable(substitution);\npass($pnum);\n");
    foreach $c (grep {!m/^no_/o} keys %{$ligclasses})
    {
        my ($gnum) = $self->{'ligmap'}{$c};
        my ($gname) = $self->{'glyphs'}[$gnum]{'name'};

        if ($type eq 'first')
        {
            $fh->print("$gname clno_$c > _:2 cl$c;\n");
        }
        else
        {
            $fh->print("clno_$c $gname > cl$c _:1;\n");
        }
    }
    $fh->print("endpass;\nendtable;\n");
}
