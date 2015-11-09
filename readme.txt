IndxCarver

This is a simple tool to dump individual INDX records. It scans the input for the signature on each sector/512 bytes. Input must be a file.

Syntax is:
IndxCarver.exe InputFile

Example 1
IndxCarver.exe c:\memdump.bin

Example 2
IndxCarver.exe c:\unallocated.chunk

If no input file is given as parameter, a fileopen dialog is launched. Output is automatically resolved based on the input name. Output is split in 3. For example 1 the output may be:
memdump.bin.2015-02-14_21-46-54.wfixups.INDX
memdump.bin.2015-02-14_21-46-54.wofixups.INDX
memdump.bin.2015-02-14_21-46-54.false.positives.INDX

This tool is handy when you have no means of accessing a healthy INDX. For instance a memory dump or damaged volume. The tool will by default first attempt to apply fixups, and if it fails it will retry by skipping fixups. Applying fixups here means verifying the update sequence array and applying it.

Memory dumps and unallocated chunks may contain numerous INDX records and that can be easily extracted. 

It is advised to check the log file generated. There will be verbose information written. Especially the false positives and their offsets can be found here, in addition to the separate output file containg all false positives.

The test of the record structure is rather comprehensive, and the output quality is excellently divided in 3.


Changelog:

1.0.0.0:
First version

1.0.0.1:
Added validation checks on data inside INDX.
Set default INDX size to 4096 bytes.
Split out in 3.

1.0.0.2:
Loosened up validation to only validate first 512 bytes, for the check without fixup.