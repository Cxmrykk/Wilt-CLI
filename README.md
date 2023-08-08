<h1 align="center">~ Wilt ~</h1>
<p align="center">CLI for Petals Chat (Web client endpoint)</p>

### Installing
#### APT-based distros (Debian, Ubuntu, etc.)
1. Import the public key to `/usr/share/keyrings`
```sh
sudo curl -o /usr/share/keyrings/cxmrykk-archive-keyring.gpg https://repo.merrick.cam/pub.gpg
```
2. Save the repository to `/etc/apt/sources.list.d/`
```sh
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cxmrykk-archive-keyring.gpg] http://repo.merrick.cam/ stable main" \
    | sudo tee /etc/apt/sources.list.d/cxmrykk.list
```
3. Update & install
```sh
sudo apt update && sudo apt install wilt
```

### Building
Make sure `crystal` and `git` are installed on the user's system.
```sh
git clone https://github.com/Cxmrykk/Wilt.git
cd Wilt
crystal build ./src/wilt.cr
```
This will produce a binary named `wilt` in the current directory.

### Executing
```
Usage: wilt [flag] | [prompt]
    -h, --help                       Prints this message
    -v, --version                    Prints the program version
    -c, --config                     Prints the configuration file path
    -l, --history                    Prints the history file path
    -f, --forget                     Forgets the last conversation
    -r, --reset-config               Resets the configuration file
```

### Configuration
Upon first execution, the program will generate a directory in the home folder containing `history.txt` and `config.json`. You can change the parameters in `config.json` as you like. A list of parameters and their functionality can be found in the [Petals Chat Repository](https://github.com/petals-infra/chat.petals.dev#http-api-apiv1).

### Example
```sh
wilt "What is the capital of France?"
```
