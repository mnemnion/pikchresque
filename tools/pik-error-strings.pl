#!/usr/bin/env perl
use strict;
use warnings;

sub decode_c_string {
  my ($s) = @_;
  $s =~ s/^"//;
  $s =~ s/"$//;
  $s =~ s/\\n/\n/g;
  $s =~ s/\\"/"/g;
  $s =~ s/\\\\/\\/g;
  return $s;
}

sub skip_ws {
  my ($src, $i) = @_;
  my $n = length($src);
  while ($i < $n && substr($src, $i, 1) =~ /\s/) { $i++; }
  return $i;
}

sub read_arg {
  my ($src, $i) = @_;
  my $n = length($src);
  my $start = $i;
  my $depth = 0;
  my $in_string = 0;
  while ($i < $n) {
    my $c = substr($src, $i, 1);
    if ($in_string) {
      if ($c eq '\\') {
        $i += 2;
        next;
      }
      if ($c eq '"') {
        $in_string = 0;
      }
      $i++;
      next;
    }
    if ($c eq '"') {
      $in_string = 1;
    } elsif ($c eq '(' || $c eq '[' || $c eq '{') {
      $depth++;
    } elsif ($c eq ')' || $c eq ']' || $c eq '}') {
      last if $depth == 0 && $c eq ')';
      $depth-- if $depth > 0;
    } elsif ($c eq ',' && $depth == 0) {
      last;
    }
    $i++;
  }
  my $arg = substr($src, $start, $i - $start);
  $arg =~ s/^\s+//;
  $arg =~ s/\s+$//;
  return ($arg, $i);
}

sub extract {
  my ($path) = @_;
  open my $fh, '<', $path or die "open $path: $!";
  local $/;
  my $src = <$fh>;
  close $fh;
  my @out;
  my $pos = 0;
  while (($pos = index($src, 'pik_error', $pos)) >= 0) {
    my $line = 1 + (substr($src, 0, $pos) =~ tr/\n//);
    my $i = skip_ws($src, $pos + length('pik_error'));
    if (substr($src, $i, 1) ne '(') {
      $pos += length('pik_error');
      next;
    }
    $i++;
    my ($a1, $j) = read_arg($src, skip_ws($src, $i));
    $j = skip_ws($src, $j);
    next unless substr($src, $j, 1) eq ',';
    my ($a2, $k) = read_arg($src, skip_ws($src, $j + 1));
    $k = skip_ws($src, $k);
    next unless substr($src, $k, 1) eq ',';
    my ($a3, $m) = read_arg($src, skip_ws($src, $k + 1));
    if ($a3 =~ /^"(?:\\.|[^"\\])*"$/) {
      push @out, [$line, decode_c_string($a3)];
    }
    $pos = $m + 1;
  }
  return @out;
}

my ($c_file, $zig_file) = @ARGV;
$c_file //= 'pikchr/pikchr.y';
$zig_file //= 'src/pikchr.zy';

my @c = extract($c_file);
my @z = extract($zig_file);

my $out_dir = 'zig-out/pik-error-strings';
mkdir 'zig-out' unless -d 'zig-out';
mkdir $out_dir unless -d $out_dir;

sub write_list {
  my ($path, $items) = @_;
  open my $fh, '>', $path or die "write $path: $!";
  for my $it (@$items) {
    my ($line, $msg) = @$it;
    $msg =~ s/\n/\\n/g;
    print $fh "$line\t$msg\n";
  }
  close $fh;
}

write_list("$out_dir/c.txt", \@c);
write_list("$out_dir/zig.txt", \@z);

my @c_msgs = map { $_->[1] } @c;
my @z_msgs = map { $_->[1] } @z;
my @c_sorted = sort @c_msgs;
my @z_sorted = sort @z_msgs;
write_list("$out_dir/c.sorted.txt", [map { [0, $_] } @c_sorted]);
write_list("$out_dir/zig.sorted.txt", [map { [0, $_] } @z_sorted]);

print "c_count=@{[scalar @c]}\n";
print "zig_count=@{[scalar @z]}\n";
print "c_list=$out_dir/c.txt\n";
print "zig_list=$out_dir/zig.txt\n";
print "c_sorted=$out_dir/c.sorted.txt\n";
print "zig_sorted=$out_dir/zig.sorted.txt\n";

exit 0 if @c_sorted == @z_sorted && join("\0", @c_sorted) eq join("\0", @z_sorted);
print "mismatch\n";
exit 1;
