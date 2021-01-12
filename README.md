#  TransLit

Program to run multiple regular expressions on a text file.

Program takes two inputs. It writes it's output to STDOUT

TransLit &lt;source file&gt; &lt;translation file&gt;

The source file is expected to be a machine language disasembly, each line in one of two forms:

Form 1: 12EF: LDA #$10 ; Comment

The first four characters are the address in hex.

Then a colon and space

Then the opcode with operands.

Then a semi-colon.

Then a comment until the end of the line.

Form 2: XXXX: freeform assembly

The XXXX causes the processor to include the data after the colon space exactly as it is typed.

The translation file is in the form of:

1&lt;tab&gt;find regex&lt;tab&gt;replace template&lt;tab&gt;label capture number

You can have as many '1' lines as you need.

The replace regex can contain '\\n' for newlines.

The 'label capture number' let's the system know which addresses need to be turned into a label.

Form 3: XXXX<tab>XXXX

This allows you to mark aread of the binary as FCB areas. In the source they must be one byte per line.

