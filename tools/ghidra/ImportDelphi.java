// Pre-analysis script: applies symbols from tools/symbols.py output.
// Ghidra detects Delphi binaries itself (borlanddelphi cspec, default convention __register).
// Args: <symbols.tsv>
//@category Delphi

import java.nio.file.Files;
import java.nio.file.Path;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.SourceType;

public class ImportDelphi extends GhidraScript {
    @Override
    public void run() throws Exception {
        int n = 0;
        for (String line : Files.readAllLines(Path.of(getScriptArgs()[0]))) {
            String[] f = line.split("\t");
            Address a = toAddr(Long.parseLong(f[0], 16));
            String name = f[3].replace(' ', '_');
            if (f[1].equals("s")) {
                try {
                    clearListing(a, a.add(Integer.parseInt(f[3])));
                    createAsciiString(a, Integer.parseInt(f[3]) + 1);
                } catch (Exception e) {
                    println("string at " + a + ": " + e.getMessage());
                }
            } else if (f[1].equals("f")) {
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
