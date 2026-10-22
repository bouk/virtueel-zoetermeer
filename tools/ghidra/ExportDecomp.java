// Post-analysis script: sets the Delphi register convention on every function and writes
// decompiled C plus disassembly for each function in the requested units.
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
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.symbol.SourceType;

public class ExportDecomp extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        Path outdir = Path.of(args[1]);
        Files.createDirectories(outdir);

        for (Function fn : currentProgram.getFunctionManager().getFunctions(true)) {
            if (!fn.isExternal() && !fn.isThunk()) {
                fn.setCallingConvention("__register");
            }
        }

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
                        s.printf("  %s  %s%n", ins.getAddress(), ins);
                    }
                }
            }
            println("Exported " + unit);
        }
        di.dispose();
    }
}
