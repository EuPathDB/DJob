package DistribJobTasks::BlastMatrixTask;

use Common::Utils;
use DistribJob::Task;
use FastaFile;
use File::Basename;

@ISA = (DistribJob::Task);

use strict;

# [name, default (or null if reqd), comment]
my @properties = 
(
 ["blastBinDir",   "",   "eg, /genomics/share/pkg/bio/ncbi-blast/latest"],
 ["dbFilePath",    "",   "full path to database file"],
 ["inputFilePath", "",   "full path to input file"],
 ["lengthCutoff",  "40",   ""],
 ["pValCutoff",    "1e-5", ""],
 ["percentCutoff", "92",   ""],
 ["endSlop",       "15",   ""],
 ["maskRepeats",   "n",  "y or n"],

 );

sub new {
    my $self = &DistribJob::Task::new(@_, \@properties);
    return $self;
}


# called once 
sub initServer {
    my ($self, $inputDir) = @_;

    my $blastBin = $self->{props}->getProp("blastBinDir");
    my $dbFilePath = $self->{props}->getProp("dbFilePath");

    if (-e "$dbFilePath.gz") {
	&runCmd("gunzip $dbFilePath.gz");
    }

    die "blastBinDir $blastBin doesn't exist" unless -e $blastBin;
    die "dbFilePath $dbFilePath doesn't exist" unless -e $dbFilePath;

    my @ls = `ls -rt $dbFilePath $dbFilePath.xn*`;
    map { chomp } @ls;  
    if (scalar(@ls) != 4 || $ls[0] ne $dbFilePath) {
	&runCmd("$blastBin/xdformat -n $dbFilePath");
    }
}

sub initNode {
    my ($self, $node, $inputDir) = @_;

    my $dbFilePath = $self->{props}->getProp("dbFilePath");
    my $nodeDir = $node->getDir();

    $node->runCmd("cp $dbFilePath.* $nodeDir");
}

sub getInputSetSize {
    my ($self, $inputDir) = @_;

    my $fastaFileName = $self->{props}->getProp("inputFilePath");

    if (-e "$fastaFileName.gz") {
	&runCmd("gunzip $fastaFileName.gz");
    }

    print "Creating index for $fastaFileName (may take a while)\n";
    $self->{fastaFile} = FastaFile->new($fastaFileName);
    return $self->{fastaFile}->getCount();
}

sub initSubTask {
    my ($self, $start, $end, $node, $inputDir, $subTaskDir, $nodeSlotDir) = @_;

    $self->{fastaFile}->writeSeqsToFile($start, $end, 
					"$subTaskDir/seqsubset.fsa");

    $node->runCmd("cp -r $subTaskDir/* $nodeSlotDir");
}

sub runSubTask { 
    my ($self, $node, $inputDir, $subTaskDir, $nodeSlotDir) = @_;

    my $blastBin = $self->{props}->getProp("blastBinDir");
    my $lengthCutoff = $self->{props}->getProp("lengthCutoff");
    my $pValCutoff = $self->{props}->getProp("pValCutoff");
    my $percentCutoff = $self->{props}->getProp("percentCutoff");
    my $endSlop = $self->{props}->getProp("endSlop");
    my $maskRepeats = $self->{props}->getProp("maskRepeats") eq "y"? "--maskRepeats" : "";
    my $dbFilePath = $self->{props}->getProp("dbFilePath");

    my $dbFile = $node->getDir() . "/" . basename($dbFilePath);

    my $cmd = "blastMatrix --blastBinDir $blastBin --db $dbFile --seqFile $nodeSlotDir/seqsubset.fsa --lengthCutoff $lengthCutoff --pValCutoff $pValCutoff --percentCutoff $percentCutoff --endSlop $endSlop $maskRepeats";
   
    $node->execSubTask("$nodeSlotDir/result", "$subTaskDir/result", $cmd);
}

sub integrateSubTaskResults {
    my ($self, $subTaskNum, $subTaskResultDir, $mainResultDir) = @_;

    &runCmd("cat $subTaskResultDir/blastMatrix.out >> $mainResultDir/blastMatrix.out");
}
1;
