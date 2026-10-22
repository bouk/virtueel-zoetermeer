// Pre-analysis script: installs the Borland "register" calling convention and applies
// symbols from tools/symbols.py output.
// Args: <symbols.tsv>
//@category Delphi

import java.nio.file.Files;
import java.nio.file.Path;

import ghidra.app.script.GhidraScript;
import ghidra.program.database.SpecExtension;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.SourceType;

public class ImportDelphi extends GhidraScript {
    static final String REGISTER_CC =
        "<prototype name=\"__register\" extrapop=\"unknown\" stackshift=\"4\">\n" +
        "  <input>\n" +
        "    <pentry minsize=\"1\" maxsize=\"4\"><register name=\"EAX\"/></pentry>\n" +
        "    <pentry minsize=\"1\" maxsize=\"4\"><register name=\"EDX\"/></pentry>\n" +
        "    <pentry minsize=\"1\" maxsize=\"4\"><register name=\"ECX\"/></pentry>\n" +
        "    <pentry minsize=\"1\" maxsize=\"500\" align=\"4\"><addr offset=\"4\" space=\"stack\"/></pentry>\n" +
        "  </input>\n" +
        "  <output>\n" +
        "    <pentry minsize=\"1\" maxsize=\"4\"><register name=\"EAX\"/></pentry>\n" +
        "    <pentry minsize=\"5\" maxsize=\"8\"><addr space=\"join\" piece1=\"EDX\" piece2=\"EAX\"/></pentry>\n" +
        "  </output>\n" +
        "  <unaffected>\n" +
        "    <register name=\"ESP\"/><register name=\"EBP\"/><register name=\"ESI\"/>\n" +
        "    <register name=\"EDI\"/><register name=\"EBX\"/>\n" +
        "  </unaffected>\n" +
        "</prototype>\n";

    @Override
    public void run() throws Exception {
        SpecExtension ext = new SpecExtension(currentProgram);
        ext.addReplaceCompilerSpecExtension(REGISTER_CC, monitor);

        int n = 0;
        for (String line : Files.readAllLines(Path.of(getScriptArgs()[0]))) {
            String[] f = line.split("\t");
            Address a = toAddr(Long.parseLong(f[0], 16));
            String name = f[3].replace(' ', '_');
            if (f[1].equals("f")) {
                disassemble(a);
                Function fn = getFunctionAt(a);
                if (fn == null) fn = createFunction(a, name);
                if (fn != null) fn.setName(name, SourceType.IMPORTED);
            } else {
                createLabel(a, name, true, SourceType.IMPORTED);
            }
            n++;
        }
        println("Applied " + n + " symbols");
    }
}
