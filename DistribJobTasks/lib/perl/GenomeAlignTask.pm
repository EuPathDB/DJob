package DJob::DistribJobTasks::GenomeAlignTask;

use DJob::DistribJob::Task;
use CBIL::Bio::FastaFile;
use File::Basename;
use Cwd;
use CBIL::Util::Utils;

@ISA = (DJob::DistribJob::Task);

use strict;

# [name, default (or null if reqd), comment]
my @properties = 
(
 ["gaBinPath",   "",   "eg, /genomics/share/bin/blat"],
 ["targetListPath",      "",     "full path to file list target files"],
 ["queryPath",   "",     "full path to input file"],
 );

sub new {
    my $self = &DJob::DistribJob::Task::new(@_, \@properties);
    return $self;
}

# called once 
sub initServer {
    my ($self, $inputDir) = @_;
    my $gaBinPath = $self->{props}->getProp("gaBinPath");
    die "gaBinPath $gaBinPath doesn't exist" unless -e $gaBinPath;
}

sub initNode {
    my ($self, $node, $inputDir) = @_;

    # my $targetListPath = $self->{props}->getProp("targetListPath");
    # my $nodeDir = $node->getDir();
    # $node->runCmd("cp $targetListPath* $nodeDir");
}

sub getInputSetSize {
    my ($self, $inputDir) = @_;

    my $fastaFileName = $self->{props}->getProp("queryPath");

    if (-e "$fastaFileName.gz") {
	&runCmd("gunzip $fastaFileName.gz");
    }

    print "Creating index for $fastaFileName (may take a while)\n";
    $self->{fastaFile} = CBIL::Bio::FastaFile->new($fastaFileName);

    return $self->{fastaFile}->getCount();
}

sub initSubTask {
    my ($self, $start, $end, $node, $inputDir, $subTaskDir, $nodeSlotDir) = @_;

    $self->{fastaFile}->writeSeqsToFile($start, $end, "$subTaskDir/seqsubset.fsa");

    $node->runCmd("cp -r $subTaskDir/* $nodeSlotDir");
}

sub runSubTask { 
    my ($self, $node, $inputDir, $subTaskDir, $nodeSlotDir) = @_;

    my $gaBinPath = $self->{props}->getProp("gaBinPath");
    my $targetListPath = $self->{props}->getProp("targetListPath");
    my $paramsPath = $inputDir . '/params.prop';

    my $cmd =  "blatSearch --blatBinPath $gaBinPath --targetListPath $targetListPath --seqPath $nodeSlotDir/seqsubset.fsa --paramsPath $paramsPath";

    $node->execSubTask("$nodeSlotDir/result", "$subTaskDir/result", $cmd);
}

sub integrateSubTaskResults {
    my ($self, $subTaskNum, $subTaskResultDir, $mainResultDir) = @_;

    opendir(STRD, $subTaskResultDir);
    my @files = readdir(STRD);
    my @chrs = grep(/chr/i, @files);
    close STRD;
    foreach my $chr (@chrs) {
	&runCmd("mkdir -p $mainResultDir/per-chr") unless -d "$mainResultDir/per-chr";
	&runCmd("cat $subTaskResultDir/$chr >> $mainResultDir/per-chr/$chr");
    }
}
1;