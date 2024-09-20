#!/usr/bin/perl
use strict;
use warnings;
use Digest::MD5 qw(md5);

# Check for the correct number of arguments
if (@ARGV != 2) {
    die "Usage: $0 <number_of_output_files> <file_prefix>\n";
}

# Get the number of output files and the file prefix from command line arguments
my ($num_files, $file_prefix) = @ARGV;

# Validate the number of output files
if ($num_files <= 0 || $num_files > 256) {
    die "Number of output files must be between 1 and 256.\n";
}

# File handles for the output files
my %file_handles;

# Read from standard input
while (<STDIN>) {
    chomp; # Remove the newline character
    my ($first_field, @rest) = split(/;/, $_, -1); # Split the line by ";"
    
    # Hash the first field
    my $hash = md5($first_field);
    
    # Get the first two bytes of the hash
    my $hash_prefix = unpack("H2", substr($hash, 0, 1));
    $hash_prefix .= unpack("H2", substr($hash, 1, 1));
    
    # Calculate the output file index
    my $file_index = (hex($hash_prefix) % $num_files);
    my $file_name = sprintf("%s.%d.s", $file_prefix, $file_index);

    # Open the output file handle if it isn't already opened
    if (!exists $file_handles{$file_index}) {
        open(my $fh, "| gzip > $file_name") or die "Cannot open file $file_name: $!";
        $file_handles{$file_index} = $fh;
    }

    # Write the line to the corresponding file
    my $fh = $file_handles{$file_index};
    print $fh "$_\n";
}

# Close all file handles
for my $fh (values %file_handles) {
    close($fh);
}
