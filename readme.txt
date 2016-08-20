IndxCarver

This is a simple tool to dump individual INDX records.  It scans the input for signatures in addition to record validations. Input must be a file.

Syntax is:
IndxCarver.exe /InputFile: /OutputPath:

Examples
IndxCarver.exe /InputFile:c:\memdump.bin
IndxCarver.exe /InputFile:c:\memdump.bin
IndxCarver.exe /InputFile:c:\unallocated.chunk /OutputPath:e:\temp
IndxCarver.exe /InputFile:c:\unallocated.chunk /OutputPath:e:\temp

If no input file is given as parameter, a fileopen dialog is launched. Output will default to program directory if omitted. Output is split in 3, in addition to a log file. Example output may look like:
Carver_Indx_2015-02-14_21-46-54.log
Carver_Indx_2015-02-14_21-46-54.wfixups.INDX
Carver_Indx_2015-02-14_21-46-54.wofixups.INDX
Carver_Indx_2015-02-14_21-46-54.false.positives.INDX

This tool is handy when you have no means of accessing a healthy INDX. For instance a memory dump or damaged volume. The tool will by default first attempt to apply fixups, and if it fails it will retry by skipping fixups. Applying fixups here means verifying the update sequence array and applying it.

Memory dumps and unallocated chunks may contain numerous INDX records and that can be easily extracted. 

It is advised to check the log file generated. There will be verbose information written. Especially the false positives and their offsets can be found here, in addition to the separate output file containg all false positives.

The test of the record structure is rather comprehensive, and the output quality is excellently divided in 3.
