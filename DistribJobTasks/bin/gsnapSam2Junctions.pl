#!/usr/bin/perl

# Modified from sam2junctions.pl by Gregory R Grant (University of Pennsylvania, 2010)

use strict;

use Getopt::Long;

my ($minsize, $samFile, $outputFile, $isBam);

&GetOptions("min_size=i"=> \$minsize,
            "input_file=s" => \$samFile,
            "output_file=s" => \$outputFile,
            "is_bam" => \$isBam,
    );

$minsize = 0 unless($minsize);;

unless(-e $samFile) {
  die "usage:  gsnapSam2Junctions.pl  --input_file=s [--min_size=i]\n";
}

my %junctions;


if($isBam) {
    $samFile = "samtools view $samFile|";
}

open(INFILE, $samFile) or die "\nError: Cannot open '$samFile' for reading\n\n";

while(my $line = <INFILE>) {
    chomp($line);
    
    my ($qname, $flag, $rname, $pos, $mapq, $cigar, $rnext, $pnext, $tlen, $seq, $qual, @tags) = split(/\t/, $line);

    next unless($cigar =~ /N/);
#    $sam_chr =~ s/:[^:]*$//;
    
    my $xs; 

    my $xo;
    foreach my $tag (@tags) {
	if($tag =~ /XS:A:([+-])/) {
	    $xs = $1;
	}
	if($tag =~ /XO:Z:(\w\w)/) {
	    $xo = $1;
	}
    }

    die "XS:A tag not found for read $qname" unless($xs);
    die "XO:Z tag not found for read $qname" unless($xo);

    my $mapperType = "nu";
    if($xo eq "CT" || $xo eq "CU" || $xo eq "HT" || $xo eq "HU" || $xo eq "PC" || $xo eq "PI" || $xo eq "PL" || $xo eq "PS" || $xo eq "UT" || $xo eq "UU") {
	$mapperType = "unique";
    }


    my $running_offset = 0;
    while($cigar =~ s/^(\d+)([^\d])//) {
	my $num = $1;
	my $type = $2;
	
	if($type eq 'N') {
	    my$start = $pos + $running_offset;
	    my $end = $start + $num - 1;
	    my $junction = "$rname:$start-$end";
	    
	    if($num >= $minsize) {
		$junctions{$junction}->{$xs}->{$mapperType}++;
	    }
	}
	
	if($type eq 'N' || $type eq 'M' || $type eq 'D') {
	    $running_offset = $running_offset + $num;
	}
    }
}
close(INFILE);



open(OUT, "> $outputFile") or die "Cannot open file $outputFile for writing: $!";


print OUT "Junction\tStrand\tUnique\tNU\n"; 

foreach my $junction (keys %junctions) {
  foreach my $xs (keys %{$junctions{$junction}}) {

    my $uniqueCount = $junctions{$junction}->{$xs}->{unique};
    my $nuCount = $junctions{$junction}->{$xs}->{nu};

    $uniqueCount = 0 unless($uniqueCount);
    $nuCount = 0 unless($nuCount);

    print OUT "$junction\t$xs\t$uniqueCount\t$nuCount\n";
  }
}

close OUT;

1;
