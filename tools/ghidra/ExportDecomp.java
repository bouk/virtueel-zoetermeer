// Postanalysisscript: schrijft de gedecompileerde C plus de disassemblage voor elke functie in de
// gevraagde units.
// Argumenten: <bereikenbestand afgeleid van units.json: "naam start eind" per regel> <uitvoermap>
//@category Delphi

import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

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

        List<String> lines = Files.readAllLines(Path.of(args[0]));
        // Delphi try/except/finally-handlers worden alleen aangeroepen via een PUSH van hun adres,
        // dus de automatische analyse laat ze ongedisassembleerd. Disassembleer ze voor de export.
        for (int pass = 0; pass < 3; pass++) {
            for (String line : lines) {
                String[] f = line.trim().split("\\s+");
                if (f.length < 3) continue;
                AddressSet range = new AddressSet(toAddr(Long.parseLong(f[1], 16)), toAddr(Long.parseLong(f[2], 16) - 1));
                List<Address> targets = new ArrayList<>();
                for (Instruction ins : currentProgram.getListing().getInstructions(range, true)) {
                    if (ins.getMnemonicString().equals("JMP")) {
                        // De code gaat verder na @HandleAnyException/@HandleFinally; een handlertabel
                        // volgt op @HandleOnException.
                        Function callee = null;
                        for (Reference ref : ins.getReferencesFrom()) callee = getFunctionAt(ref.getToAddress());
                        if (callee == null) continue;
                        Address after = ins.getMaxAddress().add(1);
                        String cn = callee.getName();
                        if (cn.equals("@HandleAnyException") || cn.equals("@HandleFinally") || cn.equals("@HandleAutoException")) {
                            if (getInstructionAt(after) == null) targets.add(after);
                        } else if (cn.equals("@HandleOnException")) {
                            try {
                                int n = getInt(after);
                                for (int i = 0; i < n && i < 32; i++) {
                                    Address h = toAddr(getInt(after.add(4 + 8 * i + 4)) & 0xffffffffL);
                                    if (range.contains(h) && getInstructionAt(h) == null) targets.add(h);
                                }
                            } catch (Exception e) {
                                println("handlertabel bij " + after + ": " + e.getMessage());
                            }
                        }
                        continue;
                    }
                    if (!ins.getMnemonicString().equals("PUSH")) continue;
                    for (Reference ref : ins.getReferencesFrom()) {
                        Address t = ref.getToAddress();
                        if (range.contains(t) && getInstructionAt(t) == null) targets.add(t);
                    }
                }
                for (Address t : targets) disassemble(t);
            }
        }

        for (String line : lines) {
            String[] f = line.trim().split("\\s+");
            if (f.length < 3) continue;
            String unit = f[0];
            Address start = toAddr(Long.parseLong(f[1], 16));
            Address end = toAddr(Long.parseLong(f[2], 16) - 1);
            List<Function> funcs = new ArrayList<>();
            for (Function fn : currentProgram.getFunctionManager().getFunctions(new AddressSet(start, end), true)) funcs.add(fn);
            try (PrintWriter c = new PrintWriter(outdir.resolve(unit + ".c").toFile());
                 PrintWriter s = new PrintWriter(outdir.resolve(unit + ".s").toFile())) {
                c.printf("// Unit %s: %s-%s%n%n", unit, start, end);
                for (int fi = 0; fi < funcs.size(); fi++) {
                    Function fn = funcs.get(fi);
                    Address next = fi + 1 < funcs.size() ? funcs.get(fi + 1).getEntryPoint().subtract(1) : end;
                    DecompileResults r = di.decompileFunction(fn, 120, monitor);
                    c.printf("// %s @ %s (%d bytes)%n", fn.getName(true), fn.getEntryPoint(), fn.getBody().getNumAddresses());
                    if (r != null && r.decompileCompleted()) {
                        c.println(r.getDecompiledFunction().getC());
                    } else {
                        c.println("// decompilatie mislukt\n");
                    }
                    s.printf("%n%s:  ; %s%n", fn.getName(true), fn.getEntryPoint());
                    for (Instruction ins : currentProgram.getListing().getInstructions(new AddressSet(fn.getEntryPoint(), next), true)) {
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
            println("Geexporteerd " + unit);
        }
        di.dispose();
    }
}
