// Post-analysis script: writes decompiled C plus disassembly for each function in the
// requested units.
// Args: <units.json-derived ranges file: "name start end" per line> <outdir>
//@category Delphi

import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileOptions;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.CodeUnitFormat;
import ghidra.program.model.listing.CodeUnitFormatOptions;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.Symbol;

public class ExportDecomp extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        Path outdir = Path.of(args[1]);
        Files.createDirectories(outdir);

        CodeUnitFormat fmt = new CodeUnitFormat(new CodeUnitFormatOptions(
            CodeUnitFormatOptions.ShowBlockName.NEVER, CodeUnitFormatOptions.ShowNamespace.ALWAYS));
        DecompInterface di = new DecompInterface();
        DecompileOptions opts = new DecompileOptions();
        di.setOptions(opts);
        di.openProgram(currentProgram);

        for (String line : Files.readAllLines(Path.of(args[0]))) {
            String[] f = line.trim().split("\\s+");
            if (f.length < 3) continue;
            String unit = f[0];
            Address start = toAddr(Long.parseLong(f[1], 16));
            Address end = toAddr(Long.parseLong(f[2], 16) - 1);
            try (PrintWriter c = new PrintWriter(outdir.resolve(unit + ".c").toFile());
                 PrintWriter s = new PrintWriter(outdir.resolve(unit + ".s").toFile())) {
                c.printf("// Unit %s: %s-%s%n%n", unit, start, end);
                for (Function fn : currentProgram.getFunctionManager().getFunctions(new AddressSet(start, end), true)) {
                    DecompileResults r = di.decompileFunction(fn, 120, monitor);
                    c.printf("// %s @ %s (%d bytes)%n", fn.getName(true), fn.getEntryPoint(), fn.getBody().getNumAddresses());
                    if (r != null && r.decompileCompleted()) {
                        c.println(r.getDecompiledFunction().getC());
                    } else {
                        c.println("// decompilation failed\n");
                    }
                    s.printf("%n%s:  ; %s%n", fn.getName(true), fn.getEntryPoint());
                    for (Instruction ins : currentProgram.getListing().getInstructions(fn.getBody(), true)) {
                        String label = "";
                        Symbol sym = currentProgram.getSymbolTable().getPrimarySymbol(ins.getAddress());
                        if (sym != null && !ins.getAddress().equals(fn.getEntryPoint())) label = sym.getName() + ":";
                        StringBuilder refs = new StringBuilder();
                        for (Reference ref : ins.getReferencesFrom()) {
                            Data d = getDataAt(ref.getToAddress());
                            if (d != null && d.hasStringValue()) refs.append(" ; \"").append(d.getValue()).append('"');
                        }
                        if (!label.isEmpty()) s.printf("%s%n", label);
                        s.printf("  %s  %s%s%n", ins.getAddress(), fmt.getRepresentationString(ins), refs);
                    }
                }
            }
            println("Exported " + unit);
        }
        di.dispose();
    }
}
