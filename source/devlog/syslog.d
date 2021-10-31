module devlog.syslog;

import std.range;
import std.algorithm.searching : countUntil;
import std.format : formattedRead;
import std.exception : enforce;

alias SDParam = const(char)[][2];

enum string[ubyte] facilityNames = [
    0: "kern",
    1: "user",
    2: "mail",
    3: "daemon",
    4: "auth",
    5: "syslog",
    6: "lpr",
    7: "news",
    8: "uucp",
    9: "cron",
    10:	"authpriv",
    11:	"ftp",
    12:	"ntp",
    13:	"security",
    14:	"console",
    15:	"solaris-cron",
    16:	"local0",
    17: "local1",
    18: "local2",
    19: "local3",
    20: "local4",
    21: "local5",
    22: "local6",
    23: "local7"
];

enum string[ubyte] severityNames = [
    0: "emerg",
    1: "alert",
    2: "crit",
    3: "err",
    4: "warning",
    5: "notice",
    6: "info",
    7: "debug"
];

struct SDElement
{
    const(char)[] name;
    SDParam[] values;
}

struct Message
{
    ubyte facility, severity;
    ubyte version_;
    const(char)[] timestamp;
    const(char)[] hostname;
    const(char)[] appName;
    const(char)[] procID;
    const(char)[] msgID;

    SDElement[] parameters;

    const(char)[] msg;
}

private char peek(const(char)[] data)
{
    enforce(!data.empty, "Unexpected end of data");
    return data[0];
}

private SDElement parseSDElement(ref const(char)[] data)
{
    SDElement result;

    // [
    data.popFront();

    // name
    const pos = data.countUntil!"a == ' ' || a == ']'";
    enforce(pos != -1, "Expected closing character for SD-ELEMENT");
    result.name = data[0 .. pos];
    data = data[pos .. $];

    // parameters
    params: while (data.peek() != ']')
    {
        // SD-PARAM
        data.popFront();
        SDParam par;
        data.formattedRead!"%s=\""(par[0]);

        char last = '"';
        for (size_t i = 0; i < data.length; i++)
        {
            if (data[i] == '"' && last != '\\')
            {
                par[1] = data[0 .. i];
                result.values ~= par;
                data = data[i + 1 .. $];
                continue params;
            }
            last = data[i];
        }
        enforce(false, "Could not find end of parameter");
    }
    data.popFront();

    return result;
}

Message parseMessage(const(char)[] data)
{
    Message result;

    // Read Header (RFC5424, Chapter 6)
    uint pri;
    data.formattedRead!"<%u> %u %s %s %s %s %s "(pri, result.version_, result.timestamp,
        result.hostname, result.appName, result.procID, result.msgID);
    result.facility = cast(ubyte)(pri / 8);
    result.severity = pri % 8;
    
    // Structured data
    if (data.peek() == '-')
    {
        data.popFront();
    }
    else
    {
        while (data.peek() == '[')
            result.parameters ~= parseSDElement(data);
    }

    // Message
    if (data.length && data.peek() == ' ')
        result.msg = data[1 .. $];

    return result;
}
