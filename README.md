# mincompile
**Detect and flag unnecessary #include directives for removal**

Overtime, "#include bloat" can creep into large projects where many files include header files that they don't actually need.

`mincompile` is a simple shell script which will try to determine what `#include`s exist in your source code that aren't necessary.

## How it works

Beware: this is not a particularly intelligent tool. It makes determinations purely by brute force, and accuracy is not guaranteed.

`mincompile` will:
- attempt to remove every `#include` in every source file in a project tree
- see if the project compiles without the `#include`
- see if the generated object file differs without the `#include`

If the project compiles fine and the generated object file is identical to the original, then the `#include` is deemed unnecessary and flagged for review.

## How To Use

Simply run `./mincompile.sh` in the root of your project directory (or wherever the makefile is)

Currently, `mincompile` will not directly remove `#include`s that it thinks are unnecessary. Instead, they will be commented out and noted with `//UNNECESSARY `, e.g. `#include "header.h"` will be turned into `//UNNECESSARY #include "header.h"`. This allows you to manually review the results for accuracy before committing them.

### Flags

`-s` or `--skip` to provide a file containing the relative paths of files *not* to scan for unnecessary `#include`s. If your makefile is not compiling part of your project, such files should be listed here so they are ignored.

## Usage Tips

- In your makefile, your `CFLAGS` should include `-Werror` so that any warnings are treated as errors. Otherwise, warnings will cause `make` to exit with exit code 0 which will trick `mincompile` into thinking everything went okay.
- In your makefile, everything in your project should be compiled by `make`. Otherwise, source code that isn't compiled will have all its `#include`s flagged for removal, since the project successfully builds without them
- Because this tool will potentially recompile your project thousands or tens of thousands of times, you should expect that it may run for a while (potentially multiple days, depending on the specs of your machine). Using a compiler cache like `ccache` may help speed up recompilations.
   - To easily install `ccache`, use [PhreakScript](https://github.com/InterLinked1/phreakscript) to run `phreaknet ccache`
