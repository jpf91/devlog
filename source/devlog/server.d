module devlog.server;

import vibe.core.net;
import devlog.syslog;
import terminal;

import std.range : empty;

enum Color[ubyte] colorMap = [
    0: Color.magenta, // "emerg"
    1: Color.magenta, // "alert"
    2: Color.red, // "crit"
    3: Color.red, // "err"
    4: Color.yellow, // "warning"
    5: Color.white, // "notice"
    6: Color.green, // "info"
    7: Color.gray // "debug"
];

enum bool[ubyte] boldMap = [
    0: true,
    1: false,
    2: true,
    3: false,
    4: false,
    5: false,
    6: false,
    7: false
];

class LogServer
{
private:
    ubyte[] _msgBuf;
    Terminal _terminal;

    static const(char)[] getTag(scope Message msg)
    {
        foreach(entry; msg.parameters)
        {
            if (entry.name == "esp")
            {
                foreach(pair; entry.values)
                {
                    if (pair[0] == "tag")
                        return pair[1];
                }
            }
        }
        return "";
    }

    void logMessage(scope Message msg)
    {
        import std.format : format;
        import std.uni : toUpper;
        import std.string : chomp;
        auto severity = severityNames[msg.severity].toUpper();
        auto tag = getTag(msg);
        if (!tag.empty)
            tag = "[" ~ tag ~ "] ";
 
        _terminal.foreground = colorMap[msg.severity];
        _terminal.bold = boldMap[msg.severity];
        _terminal.writelnr(Underlined.yes, msg.hostname, Underlined.no, "(", facilityNames[msg.facility], ") ", severity, ": ", tag, msg.msg.chomp());
        _terminal.reset();
    }

    void serveConnection(UDPConnection conn)
    {
        while (true)
        {
            const data = cast(const(char[]))conn.recv(_msgBuf);
            try
            {
                auto msg = data.parseMessage();
                logMessage(msg);
            }
            catch (Exception)
            {
                _terminal.writelnr(Foreground(Color.cyan), "Received invalid or too long message, ignoring");
            }
        }
    }

public:
    this(size_t bufferSize = 2048)
    {
        _msgBuf = new ubyte[bufferSize];
        _terminal = new Terminal();
        _terminal.title = "Syslog Receiver";
    }

    void run(NetworkAddress[] addrs)
    {
        foreach (addr; addrs)
            serveConnection(listenUDP(addr));
    }
}
