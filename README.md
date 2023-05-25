# Ziggy's Game of Life
[Conway's Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) in Zig.

Made in a couple pairing sessions at [Recurse Center](https://www.recurse.com/).

## Building
Supports Windows and MacOS. If using MacOS, make sure SDL2 is installed in your `/Library/Frameworks` path.

```sh
zig build
zig-out/bin/zgol.exe <args>
# Alternatively you can just use the run step
zig build run -- <args>
```

## Examples
Try loading an example with 
```sh
zgol -load=examples/<filename>
```

Because the grid is represented as a binary array, you can load any arbitrary data! Try loading the executable with 
```sh
zgol -load=zgol.exe
```

## Usage
Use `-help` to see CLI commands.

|Input|Action|
| --- | --- |
|Left Click|Fill Cell|
|Right Click|Erase Cell|
|Space|Toggle Simulation|
|`+`|Increase Update Speed|
|`-`|Decrease Update Speed|
|`R`|Reload file (if any)|
|`S`|Save file|

Saving will always create a new file in `<exe-directory>/saves`, named by the current timestamp. Reloading will attempt to load the latest save or the inital `-load` file.

## Built with
 - [SDL2](https://github.com/libsdl-org/SDL)
