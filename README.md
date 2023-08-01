<h1 align="center">~ Wilt ~</h1>
<p align="center">TUI for Petals Chat (Web client endpoint)</p>

### Build
Make sure `crystal` and `git` are installed on the user's system.
```sh
git clone https://github.com/Cxmrykk/Wilt.git
cd Wilt
crystal build ./src/wilt.cr
```
This will produce a binary named `wilt` in the current directory.

### Execute
```
Usage: wilt [flag] | [prompt]
    -h, --help                       Prints this message
    -v, --version                    Prints the program version
    -c, --config                     Prints the configuration file path
    -l, --history                    Prints the history file path
    -f, --forget                     Forgets the last conversation
    -r, --reset-config               Resets the configuration file
```

### Configure
Upon first execution, the program will generate a directory in the home folder containing `history.txt` and `config.json`. You can change the parameters in `config.json` as you like. Currently `top_k` and `top_p` are disabled. A list of parameters and their functionality can be found in the [Petals Chat Repository](https://github.com/petals-infra/chat.petals.dev#http-api-apiv1).

### Example
```sh
wilt "What is the capital of France?"
```
