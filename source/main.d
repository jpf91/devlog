module main;

import std.conv, std.string;
import vibe.vibe;
import devlog.server;

version(unittest) {}
else
{
    void main()
    {
        import vibe.core.args : readOption;
        string[] listen;
        NetworkAddress[] listenAddrs;
        readOption("listen", &listen, "Listen address and port (e.g. 0.0.0.0:514)");

        if (listen.empty)
        {
            listen ~= "0.0.0.0:514";
            listen ~= ":::514";
        }

        foreach(entry; listen)
        {
            auto seperator = entry.lastIndexOf(":");
            auto addr = resolveHost(entry[0 .. seperator]);
            addr.port = to!ushort(entry[seperator + 1 .. $]);
            listenAddrs ~= addr;
        }

        auto server = new LogServer();
        server.run(listenAddrs);
        runApplication();
    }
}
