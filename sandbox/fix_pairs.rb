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

module CoreExtensions
  module Time
    def date_and_time fmt="%F %T.%L"
      Object::Time.now.strftime fmt
    end

    def time_it title="", logger=AbortIf.logger, run: true
      if run
        t = Object::Time.now

        yield

        time = Object::Time.now - t

        if title == ""
          msg = "Finished in #{time} seconds"
        else
          msg = "#{title} finished in #{time} seconds"
        end

        if logger
          logger.info msg
        else
          $stderr.puts msg
        end
      end
    end
  end
end

def index_fastq fname
  index = {}
  count = 0
  seq_num = 0
  seq_offset = 0
  qual_offset = 0
  name_id = ""
  header_offset = 0 # with the @

  File.open(fname, "rt") do |f|
    f.each_line do |line|
      STDERR.printf("Reading -- %d\r", seq_num) if (seq_num % 10000).zero?

      case count
      when 0 # header
        name_id = line.chomp.split(" ")[0][1..-1]
        seq_offset = f.tell
      when 1 # seq

      when 2 # desc
        qual_offset = f.tell
      when 3 # qual
        count = -1
        index[name_id] = [header_offset, seq_offset, qual_offset]
        # outf.puts [seq_num, seq_offset, qual_offset].join "\t"
        seq_num += 1
        header_offset = f.tell
      end

      count += 1
    end
  end

  AbortIf.logger.debug { "Num seqs in '#{fname}': #{index.count}" }

  index
end

def read_record f, idx_ary
  header_offset = idx_ary[0]
  seq_offset = idx_ary[1]
  qual_offset = idx_ary[2]

  f.seek header_offset, IO::SEEK_SET
  header = f.readline.chomp

  f.seek seq_offset, IO::SEEK_SET
  seq = f.readline.chomp

  f.seek qual_offset, IO::SEEK_SET
  qual = f.readline.chomp

  "#{header}\n#{seq}\n+\n#{qual}"
end

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

  An index is used rather than reading seqs into memory.

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
Time.extend CoreExtensions::Time

forward = ARGV[0]
reverse = ARGV[1]
outbase = ARGV[2]
for_outf = "#{outbase}.1.fq"
rev_outf = "#{outbase}.2.fq"
un_outf  = "#{outbase}.U.fq"
for_idx = nil
rev_idx = nil
for_keys = nil
rev_keys = nil
paired_keys = nil
for_unpaired_keys = nil
rev_unpaired_keys = nil

Time.time_it "Indexing fastQ files" do
  for_idx = index_fastq forward
  rev_idx = index_fastq reverse
end

Time.time_it "Finding paired IDs" do
  for_keys = Set.new for_idx.keys
  rev_keys = Set.new rev_idx.keys

  paired_keys = for_keys.intersection rev_keys


  for_unpaired_keys = for_keys - paired_keys
  rev_unpaired_keys = rev_keys - paired_keys

  AbortIf.logger.debug { "Num paired keys: #{paired_keys.count}" }
  AbortIf.logger.debug { "Num for only keys: #{for_unpaired_keys.count}" }
  AbortIf.logger.debug { "Num rev only keys: #{rev_unpaired_keys.count}" }
end

begin
  forf = File.open(forward, "rt")
  revf = File.open(reverse, "rt")

  Time.time_it "Writing paired reads" do
    File.open(for_outf, "w") do |foutf|
      File.open(rev_outf, "w") do |routf|
        n = 0
        paired_keys.each do |key|
          n+=1; STDERR.printf("Reading -- %d\r", n) if (n % 10000).zero?

          for_idx_ary = for_idx[key]
          rev_idx_ary = rev_idx[key]

          foutf.puts read_record forf, for_idx_ary
          routf.puts read_record revf, rev_idx_ary
        end
      end
    end
  end

  Time.time_it "Writing un-paired reads" do
    File.open(un_outf, "w") do |f|
      n = 0
      for_unpaired_keys.each do |key|
        n+=1; STDERR.printf("Reading -- %d\r", n) if (n % 10000).zero?

        for_idx_ary = for_idx[key]

        f.puts read_record forf, for_idx_ary
      end

      n = 0
      rev_unpaired_keys.each do |key|
        n+=1; STDERR.printf("Reading -- %d\r", n) if (n % 10000).zero?

        rev_idx_ary = rev_idx[key]

        f.puts read_record revf, rev_idx_ary
      end
    end
  end
ensure
  forf.close
  revf.close
end

AbortIf.logger.info { "Surviving forward seqs: '#{for_outf}'" }
AbortIf.logger.info { "Surviving reverse seqs: '#{for_outf}'" }
AbortIf.logger.info { "Unpaired seqs: '#{un_outf}'" }
