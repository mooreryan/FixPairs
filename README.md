# FixPairs

Give it forward and reverse reads and get out still paired and un-paired reads.

- Does not depend on reads being in order
- Does not read any of the input files into memory

## Example

```bash
ruby fix_pairs.rb foward_seqs.1.fq reverse_seqs.2.fq outfile_base_name
```

Output files

```
outfile_base_name.1.fq <= surviving forward reads
outfile_base_name.2.fq <= surviving reverse reads
outfile_base_name.U.fq <= unpaired reads
```
