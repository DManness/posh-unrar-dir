A simple script to extract rar archives in a directory.

Usage: From Powershell, run `auto_unrar.ps1 "/path/to/downloads/dir"`

If run without arguments, the script will prompt for a path.

archives will be extracted to the same directory under \_unrar\_out.

You can also use task scheduler to run this script at regular intervals.
The script uses file names to track files it's already processed.
It's not the most resiliant but it works decently well..

### Installation

- Clone this repository to a location on disk
- create a folder named `bin` in the script directory.
- provide copies of `7z.exe` and `7z.dll` in the bin folder.
  - note: Do not use `7za.exe` (from the extras package) because it has no support for rar archives.