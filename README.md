# kakoune-roguelight

A silly kakoune plugin to simulate the light system seen in many rogue-like games (hence 'roguelight').

# Try it out

After sourcing the script, simply do `roguelight-enable` to enable it on the current window. Put the cursor on a space, enter insert mode (the default hook is on `InsertMove`) and move the cursor around to see the light change in real-time.

The file `map` in this repository contains a reasonably interesting map to test it on.

Spaces are considered to be transparent, everything else is opaque. The light has a radius of `roguelight_radius` (7 by default).

It should work on arbitrary input (code included), but is usually not particularly interesting.

# Algorithm

The algorithm is from [this article](https://blogs.msdn.microsoft.com/ericlippert/tag/shadowcasting/). The implementation is in pure posix shell.

# Performance

I can run it in realtime with a light radius of <= 10, but that mostly depends on hardware/key repeat rate. Probably every other programming language on earth should perform better, but this is surprisingly decent.

The code has been tested with dash, bash and busybox sh. It works best with dash.

# What's next?

Bugfixes, probably not much else. This was mostly a fun experiment (and a frustrating debugging experience).

## License

[Unlicense](http://unlicense.org)
