// Post-analysis script: builds a structure per Delphi class (inheriting ancestor fields) and
// types the Self parameter (EAX) of every Class.Method function as a pointer to it.
// Args: <ghidra-types.tsv from tools/ghidra_types.py> <project class list>
//@category Delphi

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.pcode.HighFunctionDBUtil;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.SourceType;

public class ApplyTypes extends GhidraScript {
    Map<String, Integer> sizes = new HashMap<>();
    Map<String, String> parents = new HashMap<>();
    Map<String, TreeMap<Integer, String[]>> fields = new HashMap<>();
    Map<String, StructureDataType> structs = new HashMap<>();
    DataTypeManager dtm;
    CategoryPath cat = new CategoryPath("/Delphi");

    @Override
    public void run() throws Exception {
        dtm = currentProgram.getDataTypeManager();
        for (String line : Files.readAllLines(Path.of(getScriptArgs()[0]))) {
            String[] f = line.split("\t");
            if (f[0].equals("C")) {
                sizes.put(f[1], Integer.parseInt(f[2]));
                parents.put(f[1], f.length > 3 ? f[3] : "");
            } else {
                fields.computeIfAbsent(f[1], k -> new TreeMap<>()).put(Integer.parseInt(f[2]), new String[]{f[3], f[4]});
            }
        }
        // Create empty structs first so fields can point at any class.
        for (String cls : sizes.keySet()) {
            StructureDataType s = new StructureDataType(cat, cls, Math.max(sizes.get(cls), 4), dtm);
            structs.put(cls, s);
        }
        for (String cls : sizes.keySet()) {
            StructureDataType s = structs.get(cls);
            s.replaceAtOffset(0, new PointerDataType(VoidDataType.dataType), 4, "vmt", null);
            List<String> chain = new ArrayList<>();
            for (String c = cls; c != null && !c.isEmpty(); c = parents.get(c)) chain.add(0, c);
            for (String c : chain) {
                TreeMap<Integer, String[]> fl = fields.get(c);
                if (fl == null) continue;
                for (Map.Entry<Integer, String[]> e : fl.entrySet()) {
                    DataType dt = typeFor(e.getValue()[1]);
                    int ofs = e.getKey();
                    if (ofs + dt.getLength() > s.getLength()) continue;
                    try {
                        s.replaceAtOffset(ofs, dt, dt.getLength(), e.getValue()[0], e.getValue()[1]);
                    } catch (Exception ex) {
                        println("field " + c + "+" + ofs + ": " + ex.getMessage());
                    }
                }
            }
        }
        Map<String, DataType> resolved = new HashMap<>();
        for (String cls : structs.keySet()) {
            resolved.put(cls, dtm.addDataType(structs.get(cls), DataTypeConflictHandler.REPLACE_HANDLER));
        }
        // Only project methods are typed: let the decompiler infer their parameters first and
        // commit them, then retype the first one (EAX = Self).
        Set<String> projectClasses = new HashSet<>();
        if (getScriptArgs().length > 1) {
            projectClasses.addAll(Files.readAllLines(Path.of(getScriptArgs()[1])));
        }
        DecompInterface di = new DecompInterface();
        di.openProgram(currentProgram);
        int typed = 0;
        for (Function fn : currentProgram.getFunctionManager().getFunctions(true)) {
            String name = fn.getName();
            int dot = name.indexOf('.');
            if (dot < 0) continue;
            String cls = name.substring(0, dot);
            DataType st = resolved.get(cls);
            if (st == null || !projectClasses.contains(cls)) continue;
            try {
                DecompileResults r = di.decompileFunction(fn, 60, monitor);
                if (r == null || r.getHighFunction() == null) continue;
                HighFunctionDBUtil.commitParamsToDatabase(r.getHighFunction(), true,
                    HighFunctionDBUtil.ReturnCommitOption.COMMIT, SourceType.ANALYSIS);
                Parameter[] params = fn.getParameters();
                if (params.length == 0) continue;
                params[0].setName("Self", SourceType.USER_DEFINED);
                params[0].setDataType(new PointerDataType(st), SourceType.USER_DEFINED);
                typed++;
            } catch (Exception ex) {
                println("params " + name + ": " + ex.getMessage());
            }
        }
        di.dispose();
        println("Applied " + structs.size() + " class structs, typed " + typed + " methods");
    }

    DataType typeFor(String t) {
        String l = t.toLowerCase();
        switch (l) {
            case "integer": case "longint": case "tcolor": case "thandle": case "hwnd": case "hdc":
                return IntegerDataType.dataType;
            case "cardinal": case "longword": case "dword":
                return UnsignedIntegerDataType.dataType;
            case "boolean": case "bytebool": case "byte": case "char": case "ansichar":
                return ByteDataType.dataType;
            case "smallint": case "word": case "shortint":
                return ShortDataType.dataType;
            case "single":
                return FloatDataType.dataType;
            case "double": case "real": case "tdatetime":
                return DoubleDataType.dataType;
            case "extended":
                return new ArrayDataType(ByteDataType.dataType, 10, 1);
            case "string": case "ansistring":
                return new PointerDataType(CharDataType.dataType);
            case "pointer":
                return new PointerDataType(VoidDataType.dataType);
            case "trect":
                return new ArrayDataType(IntegerDataType.dataType, 4, 4);
            case "tpoint":
                return new ArrayDataType(IntegerDataType.dataType, 2, 4);
        }
        if (l.startsWith("on") || l.endsWith("event")) {   // method pointer: Code + Data
            return new ArrayDataType(PointerDataType.dataType, 2, 4);
        }
        StructureDataType s = structs.get(t);
        if (s != null) return new PointerDataType(s);
        return Undefined4DataType.dataType;
    }
}
