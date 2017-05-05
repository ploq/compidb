import logger = std.experimental.logger;
import std.json;
import std.stdio;


struct Compiler {
    string payload;
    alias payload this;
}


struct CompilationDatabase {
    JSONValue payload;
    alias payload this;
}


struct FileName {
    string payload;
    alias payload this;
}


struct Command {
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


struct Makefile {
    MakefileRule[] rules;
    RuleName[] rules_name;
}


Command compilerEdit(Command cmd, Compiler new_cc) {
    import std.algorithm : splitter, joiner;
    import std.conv : to;
    import std.array : array;
    
    auto s = splitter(to!string(cmd), " ").array;
    s[0] = new_cc;


    return Command(to!string(s.joiner(" ")));
}

Makefile toMakefile(CompilationDatabase comp_db, Compiler cc, Flags flags) {
    import std.path : baseName;
    import std.array : split;

    Makefile make_out;
    string[] rules_name;
    for(int i = 0; i < comp_db.array.length; i++) {
        RuleName name = RuleName(baseName(comp_db[i]["file"].str) ~ ".o");
        Command command = compilerEdit(Command(comp_db[i]["command"].str ~ " " ~ flags), cc);

        make_out.rules_name ~= name;
        make_out.rules ~= MakefileRule(name, command);
    }

    return make_out;
}

Makefile toMakefile(CompilationDatabase comp_db, Compiler cc) {
    import std.path : baseName;
    import std.array : split;

    Makefile make_out;
    string[] rules_name;
    for(int i = 0; i < comp_db.array.length; i++) {
        RuleName name = RuleName(baseName(comp_db[i]["file"].str) ~ ".o");
        Command command = compilerEdit(Command(comp_db[i]["command"].str), cc);

        make_out.rules_name ~= name;
        make_out.rules ~= MakefileRule(name, command);
    }

    return make_out;
}

Makefile toMakefile(CompilationDatabase comp_db, Flags flags) {
    import std.path : baseName;
    import std.array : split;

    Makefile make_out;
    string[] rules_name;
    for(int i = 0; i < comp_db.array.length; i++) {
        RuleName name = RuleName(baseName(comp_db[i]["file"].str) ~ ".o");
        Command command = Command(comp_db[i]["command"].str ~ " " ~ flags);

        make_out.rules_name ~= name;
        make_out.rules ~= MakefileRule(name, command);
    }

    return make_out;
}

Makefile toMakefile(CompilationDatabase comp_db) {
    import std.path : baseName;
    import std.array : split;

    Makefile make_out;
    string[] rules_name;
    for(int i = 0; i < comp_db.array.length; i++) {
        RuleName name = RuleName(baseName(comp_db[i]["file"].str) ~ ".o");
        Command command = Command(comp_db[i]["command"].str);

        make_out.rules_name ~= name;
        make_out.rules ~= MakefileRule(name, command);
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


CompilationDatabase parse(FileName file_name) {
    import std.file : readText;

    string json = readText(file_name);
    return CompilationDatabase(parseJSON(json));
}


int main(string[] args) {
    import std.file : write;
    import std.getopt;

    string compiler;
    string compilation_database;
    string addtional_flags;
    string output_makefile = "Makefile";

    try {
        auto helpInformation = getopt(
            args,
            std.getopt.config.passThrough,
            "compile-db|c", "REQUIRED: compilation database to make into a Makefile", &compilation_database,
            "compiler|x", "OPTIONAL: Change the compiler", &compiler,
            "addtional-flags|f", "OPTIONAL: Additional flags to supply to the compiler", &addtional_flags,
            "output|o", "OPTIONAL: output file name", &output_makefile);

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

        CompilationDatabase comp_db = parse(FileName(compilation_database));

        if (compiler.length != 0 && addtional_flags.length != 0) {
            write(output_makefile, (generate(toMakefile(comp_db, Compiler(compiler), Flags(addtional_flags)))));
        } else if(compiler.length != 0 && addtional_flags.length == 0) {
            write(output_makefile, (generate(toMakefile(comp_db, Compiler(compiler)))));
        } else if(compiler.length == 0 && addtional_flags.length != 0) {
            write(output_makefile, (generate(toMakefile(comp_db, Flags(addtional_flags)))));
        } else {
            write(output_makefile, (generate(toMakefile(comp_db))));
        }

    } catch(GetOptException e) {
        writeln("Unknown flag in arguments...");
        return 1;

    }

    return 0;
}   
