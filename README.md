# FixPairs

Do you have some messed up read pairings? We can fix that!!!

Give it forward and reverse reads and get out reads that are still paired and those that are broken up.

## Installation

### Binaries

I've got some binaries for you!

- Fedora release 23 (64 bit)
- Mac OSX Yosimite (10.10.5)

Check the bin folder. Or the [releases tab](https://github.com/mooreryan/FixPairs/releases) on github.

### Compilation

It requires c++11. Using `g++` the following command will compile the program.

```
g++ -g -Wall --std=c++11 fix_pairs.cc -o FixPairs
```

Then, if you want, move the `FixPairs` binary file to somewhere on your path.

```
mv FixPairs ~/bin
```

## Example

Running this command

```bash
FixPairs foward_seqs.1.fq reverse_seqs.2.fq outfile_base_name
```

Will output the following files

```
outfile_base_name.1.fq <= surviving forward reads
outfile_base_name.2.fq <= surviving reverse reads
outfile_base_name.U.fq <= unpaired reads
```

And this cute little report!

```
----Results-------------------------------------------------
Num input forward reads:   2327528
Num input reverse reads:   2327448
Total input reads:         4654976

Num surviving read pairs:  2327412
Num broken forward reads:  116
Num broken reverse reads:  36
Total reads accounted for: 4654976
------------------------------------------------------------
```

## Some Details

### Read pairing

Assumes that the paired reads have headers that match up until the first space like these:

```
@SN741:746:HKFKLBCXX:1:1106:19267:2152 1:N:0:TGCGTAAC
@SN741:746:HKFKLBCXX:1:1106:19267:2152 2:N:0:TGCGTAAC
^ from here...they match...till here ^
```

### Other stuff

This program does not...

- Check that each sequence has proper Illumina forward or reverse tag (make sure you specify the correct files on the command line!)
- Require the files to be sorted in any particular order (it can handle even jumbled up files!)
- Read both input files into memory (just the forward reads)

### Read order

The order of the sequences in the output files may be a little weird.

- The `.1.fq` and `.2.fq` files will be ordered as the reads in the input reverse file.
- The `.U.fq` file will start with reads from the input reverse file in the order they appear, and then continue with the unpaired foward reads in an unspecified order.