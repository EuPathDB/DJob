package DJob::DistribJobTasks::BowtieMappingTask;

use DJob::DistribJob::Task;
use CBIL::Bio::FastaFileSequential;
use File::Basename;
use Cwd;
use CBIL::Util::Utils;

@ISA = (DJob::DistribJob::Task);

use strict;

# [name, default (or null if reqd), comment]
my @properties = 
(
	["fastaFile", "", "full path of fastaFile for genome"],
	["mateA", "none", "full path to file of reads"],
	["mateB", "none", "full path to file of paired ends reads"],
	["outputPrefix", "result", "prefix of output files"],
	["bowtieIndex", "none", "full path of the bowtie indices .. likely same as fasta file"],
	["isColorspace", "false", "input sequence reads are in SOLiD colorspace.  Quality files must be exactly matename.qual"],
    ["removePCRDuplicates", "true", "remove PCR duplicates for any analysis involving read depth, e.g., ploidy, CNV, mapping replication origins"],
	["bowtie2", "default", "full path to the bowtie2 bin dir"],
	["sampleName", "", "strain to be put into output"],
	["deleteIntermediateFiles", "true", "[true]|false: if true then deletes intermediate files to save space"]
);

sub new {
    my $self = &DJob::DistribJob::Task::new(@_, \@properties);
    return $self;
}

# called once 
sub initServer {
  my ($self, $inputDir) = @_;
}

sub initNode {
    my ($self, $node, $inputDir) = @_;
}

sub getInputSetSize {
    my ($self, $inputDir) = @_;
    return 1;
}

sub initSubTask {
    my ($self, $start, $end, $node, $inputDir, $serverSubTaskDir, $nodeExecDir,$subTask) = @_;
}

sub makeSubTaskCommand { 
    my ($self, $node, $inputDir, $nodeExecDir) = @_;

    my $fastaFile = $self->getProperty ("fastaFile");
    my $mateA = $self->getProperty ("mateA");
    my $mateB = $self->getProperty ("mateB");
    my $outputPrefix = $self->getProperty ("outputPrefix");
    my $bowtieIndex = $self->getProperty ("bowtieIndex");
    my $isColorSpace = $self->getProperty ("isColorSpace");
    my $removePCRDuplicates = $self->getProperty ("removePCRDuplicates");
    my $extraBowtieParams = $self->getProperty ("extraBowtieParams");
    my $sampleName = $self->getProperty ("sampleName");
    my $wDir = "$node->{masterDir}/mainresult";
    my $bowtie2 = $self->getProperty ("bowtie2");


    if ($fastaFile !~ /\.fa/ || $fastaFile !~ /\.fasta/) {
        my $tempFile = $fastaFile;
        $tempFile =~ s/\.\w+$/\.fa/;
        `ln -s $fastaFile $tempFile` unless (-e $tempFile);
        $fastaFile = $tempFile;
    }
    
    my $cmd = "runBowtieMapping.pl --fastaFile $fastaFile --mateA $mateA".(-e "$mateB" ? " --mateB $mateB" : "");
    $cmd .= " --outputPrefix $outputPrefix --bowtieIndex $bowtieIndex";
    $cmd .= " --bowtie2 $bowtie2 --extraBowtieParams $extraBowtieParams";
    if($self->getProperty('isColorspace') eq 'true'){
      $cmd .= " --isColorspace";
    }
    if ($self->getProperty('removePCRDuplicates') eq 'true'){
      $cmd.= " --removePCRDuplicates";
    }
    $cmd .= " --sampleName $sampleName";
    $cmd .= " --workingDir $wDir" . ($self->getProperty('deleteIntermediateFiles') eq 'true' ? " --deleteIntermediateFiles" : "");
      
#    print "Returning command: $cmd\n";
#    exit(0);  ##for testing
    return $cmd;
}

##cleanup materDir here and remove extra files that don't want to transfer back to compute node
sub integrateSubTaskResults {
    my ($self, $subTaskNum, $node, $nodeExecDir, $mainResultDir) = @_;
}

sub cleanUpServer {
  my($self, $inputDir, $mainResultDir, $node) = @_;
  }

1;
