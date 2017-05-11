import logger = std.experimental.logger;
import std.json;
import std.stdio;

import std.algorithm : canFind;


auto plausableCompilers = ["g++", "gcc", "clang", "clang++"];


struct Compiler {
    string payload;
    alias payload this;
}


struct CompilationDatabase {
    CDBFileName name;
    JSONValue payload;
    alias payload this;
}


struct CDBFileName {
    string payload;
    alias payload this;
}


struct Command {
    string payload;
    alias payload this;
}


struct OutputDir {
    string payload;
    alias payload this;
}


struct Flags {
    string payload;
    alias payload this;
}


struct RuleName {
    string payload;
    alias payload this;
}


struct MakefileRule {
    RuleName name;
    Command command;
}

struct OutputFile {
    string payload;
    alias payload this;
}

struct Makefile {
    MakefileRule[] rules;
    RuleName[] rules_name;
    OutputFile[] outputs;
}

Compiler getCompiler(Makefile makefile) {
    import std.array : array;
    import std.algorithm : splitter;
    import std.conv : to;

    return Compiler(splitter(to!string(makefile.rules[0].command), " ").array[0]);
}

Compiler getCompiler(Command command) {
    import std.algorithm : splitter;
    import std.array : array;
    import std.conv : to;
    writeln("woo");
    return Compiler(splitter(to!string(command), " ").array[0].splitter("/").array[$-1]);
}

bool isCompiler(Compiler compiler) {
    import std.algorithm : canFind;
    return plausableCompilers.canFind(compiler);
}

Command absPaths(Command cmd, string base) {
    //buildNormalizedPath
    import std.algorithm : splitter;
    import std.path : absolutePath, buildNormalizedPath;
    import std.conv : to;

    Command new_cmd;
    auto s = splitter(to!string(cmd), " ");
    foreach(flag ; s) {
        if(flag.length != 0 && flag[0..2] == "-I") {
            new_cmd.payload ~= " -I" ~ absolutePath(buildNormalizedPath(flag[2..$]), base) ~ " ";
        } else if(flag.length != 0 && (flag[0] == '.' || flag[1] == '/')) {
            new_cmd.payload ~= " " ~ absolutePath(buildNormalizedPath(flag), base) ~ " ";
        } else {
            new_cmd.payload ~= " " ~ flag ~ " ";
        }
    }
    return new_cmd;
}

OutputFile getOutputFile(Command cmd) {
    import std.conv : to;
    import std.algorithm : splitter, countUntil;
    import std.array : array;
    auto s = splitter(cmd.payload, " ").array;
    auto index = to!int(s.countUntil("-o"));
    if (index == -1) {
        return OutputFile("");
    }
    return OutputFile(s[index+1]);
}

Command outputPurge(Command cmd) {
    import std.algorithm : splitter, joiner, countUntil;
    import std.array : array;
    import std.conv : to;
    import std.path : baseName;

    auto s = splitter(cmd.payload, " ").array;
    auto index = to!int(s.countUntil("-o"));
    s[index+1] = baseName(s[index+1]);

    return Command(to!string(s.joiner(" ")));

}

Command compilerEdit(Command cmd, Compiler new_cc) {
    import std.algorithm : splitter, joiner;
    import std.conv : to;
    import std.array : array;
    
    auto s = splitter(to!string(cmd), " ").array;
    s[0] = new_cc;


    return Command(to!string(s.joiner(" ")));
}

Makefile toMakefile(CompilationDatabase comp_db, Compiler cc, Flags flags, bool out_dir) {
    import std.path : baseName, dirName;
    import std.array : split;

    Makefile make_out;
    string[] rules_name;
    for(int i = 0; i < comp_db.array.length; i++) {
        RuleName name = RuleName(baseName(comp_db[i]["file"].str) ~ ".o");
        Command cmd = Command(comp_db[i]["command"].str);

        if (make_out.rules_name.canFind(name)) {
            name = name.payload ~ ".pp";
        }

        if (isCompiler(getCompiler(cmd))) {
            cmd = compilerEdit(Command(cmd.payload ~ flags), cc);
        }

        if (out_dir) {
            cmd = outputPurge(cmd);
        }

        cmd = absPaths(cmd, dirName(comp_db.name));

        make_out.rules_name ~= name;
        make_out.rules ~= MakefileRule(name, cmd);
        make_out.outputs ~= getOutputFile(cmd);
    }

    return make_out;
}

Makefile toMakefile(CompilationDatabase comp_db, Compiler cc, bool out_dir) {
    import std.path : baseName, dirName;
    import std.array : split;

    Makefile make_out;
    string[] rules_name;
    for(int i = 0; i < comp_db.array.length; i++) {
        RuleName name = RuleName(baseName(comp_db[i]["file"].str) ~ ".o");
        Command cmd = Command(comp_db[i]["command"].str);
        if (make_out.rules_name.canFind(name)) {
            name = name.payload ~ ".pp";
        }
        if (isCompiler(getCompiler(cmd))) {
            cmd = compilerEdit(cmd, cc);
        }

        if (out_dir) {
            cmd = outputPurge(cmd);
        }

        cmd = absPaths(cmd, dirName(comp_db.name));

        make_out.rules_name ~= name;
        make_out.rules ~= MakefileRule(name, cmd);
        make_out.outputs ~= getOutputFile(cmd);
    }

    return make_out;
}

Makefile toMakefile(CompilationDatabase comp_db, Flags flags, bool out_dir) {
    import std.path : baseName, dirName;
    import std.array : split;

    Makefile make_out;
    string[] rules_name;
    for(int i = 0; i < comp_db.array.length; i++) {
        RuleName name = RuleName(baseName(comp_db[i]["file"].str) ~ ".o");
        Command cmd = Command(comp_db[i]["command"].str);
        if (make_out.rules_name.canFind(name)) {
            name = name.payload ~ ".pp";
        }
        
        if (isCompiler(getCompiler(cmd))) {
            cmd = Command(cmd.payload ~ " " ~ flags);
        }

        if (out_dir) {
            cmd = outputPurge(cmd);
        }

        cmd = absPaths(cmd, dirName(comp_db.name));

        make_out.rules_name ~= name;
        make_out.rules ~= MakefileRule(name, cmd);
        make_out.outputs ~= getOutputFile(cmd);
    }

    return make_out;
}

Makefile toMakefile(CompilationDatabase comp_db, bool out_dir) {
    import std.path : baseName, dirName;
    import std.array : split;

    Makefile make_out;
    string[] rules_name;

    for(int i = 0; i < comp_db.array.length; i++) {
        RuleName name = RuleName(baseName(comp_db[i]["file"].str) ~ ".o");
        Command cmd = Command(comp_db[i]["command"].str);
        if (make_out.rules_name.canFind(name)) {
            name = name.payload ~ ".pp";
        }

        if (out_dir) {
            cmd = outputPurge(cmd);
        }
        
        cmd = absPaths(cmd, dirName(comp_db.name));

        make_out.rules_name ~= name;
        make_out.rules ~= MakefileRule(name, cmd);
        make_out.outputs ~= getOutputFile(cmd);
    }

    return make_out;
}


string generate(Makefile file) {
    import std.format : format;
    import std.algorithm : joiner;
    string out_file;

    out_file ~= format("all: %s\n\n", file.rules_name.joiner(" "));
    
    foreach(rule ; file.rules) {
        out_file ~= format("%s:\n\t%s\n", rule.name, rule.command);
    }

    return out_file;
}


CompilationDatabase parse(CDBFileName file_name) {
    import std.file : readText;

    string json = readText(file_name);
    return CompilationDatabase(file_name, parseJSON(json));
}

version(all) {
int main(string[] args) {
    import std.file : write;
    import std.getopt;
    import std.path;

    string compiler;
    string compilation_database;
    string addtional_flags;
    string output_makefile = "Makefile";
    bool output_edit = false;

    try {
        auto helpInformation = getopt(
            args,
            std.getopt.config.passThrough,
            "compile-db|c", "REQUIRED: compilation database to make into a Makefile", &compilation_database,
            "compiler|x", "OPTIONAL: Change the compiler", &compiler,
            "addtional-flags|f", "OPTIONAL: Additional flags to supply to the compiler", &addtional_flags,
            "output|o", "OPTIONAL: output file name", &output_makefile,
            "output-purge|p", "OPTIONAL: purges the output flag to same directory", &output_edit);

        if (helpInformation.helpWanted)
        {
            defaultGetoptPrinter("Usage:",
                    helpInformation.options);
            return 1;
        }

        if(compilation_database.length == 0) {
            defaultGetoptPrinter("Usage:",
                    helpInformation.options);
            return 1;
        }

        CompilationDatabase comp_db = parse(CDBFileName(compilation_database));

        if (compiler.length != 0 && addtional_flags.length != 0) {
            write(output_makefile, (generate(toMakefile(comp_db, Compiler(compiler), Flags(addtional_flags), output_edit))));
        } else if(compiler.length != 0 && addtional_flags.length == 0) {
            write(output_makefile, (generate(toMakefile(comp_db, Compiler(compiler), output_edit))));
        } else if(compiler.length == 0 && addtional_flags.length != 0) {
            write(output_makefile, (generate(toMakefile(comp_db, Flags(addtional_flags), output_edit))));
        } else if(compiler.length == 0 && addtional_flags.length == 0) {
            write(output_makefile, (generate(toMakefile(comp_db, output_edit))));
        }

    } catch(GetOptException e) {
        writeln("Unknown flag in arguments...");
        return 1;

    }

    return 0;
}   
}


