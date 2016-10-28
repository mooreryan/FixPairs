#!/usr/bin/env ruby

# Copyright 2016 Ryan Moore
# Contact: moorer@udel.edu
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see
# <http://www.gnu.org/licenses/>.

require "set"
require "trollop"
require "abort_if"
require "parse_fasta"

opts = Trollop.options do
  version "Version: fix_pairs.rb v0.1.0"
  banner <<-EOS

  Assumes that the paired reads have headers that match up until the
  first space like these:

    @SN741:746:HKFKLBCXX:1:1106:19267:2152 1:N:0:TGCGTAAC
    @SN741:746:HKFKLBCXX:1:1106:19267:2152 2:N:0:TGCGTAAC
    ^ from here...they match...till here ^

  This program does not check that every sequence has the proper
  Illumina forward or reverse tag. It assumes that you have the
  correct reads in the correct command line args.

  This one reads seqs into memory. Order of the output file will be
  order of reverse reads file.

  Usage:
    ruby fix_pairs.rb foward_seqs.1.fq reverse_seqs.2.fq outfile_base_name

  Output files (given the above command):
    outfile_base_name.1.fq <= surviving forward reads
    outfile_base_name.2.fq <= surviving reverse reads
    outfile_base_name.U.fq <= unpaired reads

  Options:
  EOS
end

include AbortIf

forward = ARGV[0]
reverse = ARGV[1]
outbase = ARGV[2]




for_recs = {}
n = 0
ParseFasta::SeqFile.open(forward).each_record do |rec|
  n+=1; STDERR.printf("READING -- #{forward} -- %d\r", n) if (n%10000).zero?
  id = rec.header.split(" ")[0]

  for_recs[id] = rec
end
STDERR.puts

paired_ids = []

begin
  for_outf = File.open "#{outbase}.1.fq", "w"
  rev_outf = File.open "#{outbase}.2.fq", "w"
  un_outf  = File.open "#{outbase}.U.fq", "w"

  n = 0
  ParseFasta::SeqFile.open(reverse).each_record do |rec|
    n+=1; STDERR.printf("READING -- #{reverse} -- %d\r", n) if (n%10000).zero?

    id = rec.header.split(" ")[0]

    if for_recs.has_key? id
      for_outf.puts for_recs[id]
      rev_outf.puts rec
      paired_ids << id
    else
      un_outf.puts rec
    end
  end
  STDERR.puts

  for_unpaired = for_recs.keys - paired_ids

  n = 0
  for_unpaired.each do |id|
    n+=1; STDERR.printf("WRITING -- Forward unpaired -- %d\r", n) if (n%10000).zero?

    un_outf.puts for_recs[id]
  end
  STDERR.puts

  AbortIf.logger.info { "Surviving forward seqs: '#{for_outf.path}'" }
  AbortIf.logger.info { "Surviving reverse seqs: '#{rev_outf.path}'" }
  AbortIf.logger.info { "Unpaired seqs: '#{un_outf.path}'" }
ensure
  for_outf.close if for_outf
  rev_outf.close if rev_outf
  un_outf.close  if un_outf
end
