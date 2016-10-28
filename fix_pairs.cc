// Copyright 2016 Ryan Moore
// Contact: moorer@udel.edu

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see
// <http://www.gnu.org/licenses/>.

// Compile with g++ -g -Wall --std=c++11 test.cc -o test

#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

// see http://stackoverflow.com/questions/236129/split-a-string-in-c
std::string get_id(const std::string &header) {
  std::stringstream ss;
  ss.str(header);
  std::string id;

  std::getline(ss, id, ' ');
  return id;
}

char * check_asprintf(char * basename, const char * suffix)
{
  char * str;
  if (asprintf(&str, "%s%s", basename, suffix) == -1) {
    std::cerr << "ERROR -- Memory error in allocating file name for "
              << basename
              << suffix
              << std::endl;

    exit(2);
  }

  return str;
}

void check_open(std::ofstream * stream, char * name)
{
  stream->open(name);

  if (!stream->is_open()) {
    std::cerr << "Couldn't open "
              << name
              << " for writing"
              << std::endl;

    exit(3);
  }
}

int main(int argc, char *argv[])
{

  if (argc != 4) {
    std::cerr << "USAGE: "
              << argv[0]
              << " reads.1.fq reads.2.fq outfile_basename"
              << std::endl;

    return 1;
  }

  int lineno = -1;

  long int nf = 0;
  long int nr = 0;
  long int num_surviving_pairs = 0;
  long int num_broken_forward = 0;
  long int num_broken_reverse = 0;

  std::string line, header, seq, comment, qual, rec_str;

  std::ifstream forward (argv[1]);
  std::ifstream reverse (argv[2]);

  std::ofstream for_outf;
  std::ofstream rev_outf;
  std::ofstream unp_outf;

  std::unordered_map<std::string, std::string> recs;
  std::unordered_map<std::string, std::string>::const_iterator iter;

  char * for_outf_name;
  char * rev_outf_name;
  char * unp_outf_name;

  for_outf_name = check_asprintf(argv[3], ".1.fq");
  rev_outf_name = check_asprintf(argv[3], ".2.fq");
  unp_outf_name = check_asprintf(argv[3], ".U.fq");

  check_open(&for_outf, for_outf_name);
  free(for_outf_name);

  check_open(&rev_outf, rev_outf_name);
  free(rev_outf_name);

  check_open(&unp_outf, unp_outf_name);
  free(unp_outf_name);

  if (forward.is_open()) {
    while (std::getline(forward, line)) {
      ++lineno;

      if (lineno == 0) { // header
        header = line;
      } else if (lineno == 1) { // seq
        seq = line;
      } else if (lineno == 2) { // comment
        comment = line;
      } else if (lineno == 3) { // qual
        if (++nf % 10000 == 0) {
          std::cerr << "Reading forward -- "
                    << nf
                    << "\r";
        }

        qual = line;

        rec_str = header + "\n" + seq + "\n" + comment + "\n" + qual;

        // do the stuff
        recs.emplace(get_id(header), rec_str);

        // reset vals for next record
        lineno  = -1;
        header  = "";
        seq     = "";
        comment = "";
        qual    = "";
      }
    }
  } else {
    std::cerr << "ERROR -- cannot read "
              << argv[1]
              << std::endl;
    exit(4);
  }

  if (reverse.is_open()) {
    // do stuff
    while (std::getline(reverse, line)) {
      ++lineno;

      if (lineno == 0) { // header
        header = line;
      } else if (lineno == 1) { // seq
        seq = line;
      } else if (lineno == 2) { // comment
        comment = line;
      } else if (lineno == 3) { // qual
        if (++nr % 10000 == 0) {
          std::cerr << "Reading reverse -- "
                    << nr
                    << "\r";
        }

        qual = line;

        rec_str = header + "\n" + seq + "\n" + comment + "\n" + qual;

        // check for key
        iter = recs.find(get_id(header));

        if (iter != recs.end()) { // key found
          ++num_surviving_pairs;

          // print the record in recs in the forward file
          for_outf << iter->second << std::endl;

          // print this record in the reverse file
          rev_outf << rec_str << std::endl;

          // delete the id from the map cos it has already been printed
          recs.erase(iter);
        } else {
          ++num_broken_reverse;
          // print this record in the unpaired file
          unp_outf << rec_str << std::endl;
        }

        // reset vals for next record
        lineno  = -1;
        header  = "";
        seq     = "";
        comment = "";
        qual    = "";
      }
    }
  } else {
    std::cerr << "ERROR -- cannot read "
              << argv[2]
              << std::endl;

    exit(5);
  }

  // print the unpaired forward ids
  for (iter = recs.begin(); iter != recs.end(); ++iter) {
    ++num_broken_forward;

    unp_outf << iter->second
             << std::endl;
  }


  for_outf.close();
  rev_outf.close();
  unp_outf.close();

  std::cerr << "\n\n----Results-------------------------------------------------\n";
  std::cerr << "Num input forward reads:   " << nf << std::endl;
  std::cerr << "Num input reverse reads:   " << nr << std::endl;
  std::cerr << "Total input reads:         " << nr + nf << std::endl;
  std::cerr << std::endl;
  std::cerr << "Num surviving read pairs:  " << num_surviving_pairs << std::endl;
  std::cerr << "Num broken forward reads:  " << num_broken_forward << std::endl;
  std::cerr << "Num broken reverse reads:  " << num_broken_reverse << std::endl;
  std::cerr << "Total reads accounted for: " <<
    num_broken_reverse + num_broken_forward + (2 * num_surviving_pairs) << std::endl;
  std::cerr << "------------------------------------------------------------" << "\n\n\n";


  return 0;
}
