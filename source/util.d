import std.stdio;

void warn(T...)(T t) {
    stderr.writeln(t);
}
