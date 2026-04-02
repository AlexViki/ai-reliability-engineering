# Install asciinema CLI
asciinema CLI is available in most package repositories on Linux, macOS, and FreeBSD. Search for a package named asciinema.
```bash
sudo apt install asciinema
```

## Record a terminal session
To start a recording session use the rec command:
```bash
asciinema rec demo.cast
```
When done, press ctrl+d or enter exit to end the recording.
Instead of recording a shell you can record any command with --command / -c option:
```bash
asciinema rec -c htop demo.cast
```
The recording ends when you exit htop by pressing its q shortcut.
Run asciinema rec --help for all recording options.

### Record a lab session
```bash
asciinema rec --overwrite -c "./asciinema/asciinema_lab_1.sh" ./asciinema/lab_1.cast
asciinema rec --overwrite -c "./asciinema/asciinema_lab_2.sh" ./asciinema/lab_2.cast
asciinema rec --overwrite -c "./asciinema/asciinema_lab_3.sh" ./asciinema/lab_3.cast
asciinema rec --overwrite -c "./asciinema/asciinema_lab_4.sh" ./asciinema/lab_4.cast
```

### Upload to asciinema.org
```bash
asciinema upload ./asciinema/lab_1.cast
asciinema upload ./asciinema/lab_2.cast
asciinema upload ./asciinema/lab_3.cast
asciinema upload ./asciinema/lab_4.cast
```

### Links:
```
lab_4: https://asciinema.org/a/uuAfft1ulEpOMFRx
```

## Replay directly in a terminal
To replay a recording in your terminal use the play command
```bash
asciinema play demo.cast
```

### Replay a lab session
```bash
asciinema play ./asciinema/lab_1.cast
asciinema play ./asciinema/lab_2.cast
asciinema play ./asciinema/lab_3.cast
asciinema play ./asciinema/lab_4.cast
```

To replay it with double speed use --speed / -s option:
```bash
asciinema play -s 2 demo.cast
```
A unique feature of asciinema is the ability to optimize away idle moments in a recording using the --idle-time-limit / -i option:
```bash
asciinema play -i 2 demo.cast
```
You can pass -i 2 to asciinema rec as well, to set it permanently on a recording. Idle time limiting makes the recordings much more interesting to watch. Try it!
Run asciinema play --help for all playback options.

