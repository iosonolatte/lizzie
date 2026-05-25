# Lizzie - Leela Zero Interface

![screenshot](https://raw.githubusercontent.com/featurecat/lizzie/master/screenshot0.7.jpg?raw=true)

Lizzie is a graphical interface allowing the user to analyze games in
real time using [Leela Zero](https://github.com/gcp/leela-zero). You
need Java 11 or higher to run this program.

See the [Wiki](https://github.com/featurecat/lizzie/wiki) for learning more.

[![Build](https://github.com/featurecat/lizzie/actions/workflows/build.yml/badge.svg)](https://github.com/featurecat/lizzie/actions/workflows/build.yml)

## Table of Contents

- [Running a release](#running-a-release)
- [Building from source](#building-from-source)
  - [Building Leela Zero](#building-leela-zero)
  - [Building Lizzie](#building-lizzie)
  - [Running Lizzie](#running-lizzie)
- [Usage tips](#usage-tips)
- [Contributing](#contributing)

## Running a release

The recommended way to use Lizzie is to download a prebuilt release. Grab
the latest archive from the
[Releases page](https://github.com/featurecat/lizzie/releases/latest)
and follow the instructions in the bundled `readme`.

The first run may take a while because Leela Zero needs to set up the
OpenCL tunings. Just hang tight, and wait for it to finish, then you
will see Leela Zero's analysis displayed on the board. Feel free to supply
your own tunings, as this will speed up the process. Do this by copying
any `leelaz_opencl_tuning` file you have into the directory.

## Building from source

You will need:

- **JDK 11 or newer** (e.g. [Eclipse Temurin](https://adoptium.net/))
- **[Apache Maven](https://maven.apache.org/) 3.6+**
- A working **Leela Zero** binary (built or downloaded — see below)

### Building Leela Zero

First, you will need to have a version of Leela Zero that
continually outputs pondering information. You can get this from one
of the Lizzie releases or build it yourself; just compile from the **next**
branch of Leela Zero (see https://github.com/gcp/leela-zero/tree/next for more
details).

    $ git clone --recursive --branch next https://github.com/gcp/leela-zero.git

### Building Lizzie

The simplest way to build Lizzie is to use [Maven](https://maven.apache.org/).

To build the code, run the unit tests and produce a runnable shaded JAR:

    $ mvn clean package

The build artifacts are written to `target/`. The runnable file is the
one with the `-shaded` suffix, e.g. `target/lizzie-<version>-shaded.jar`.

### Running Lizzie

    $ java -jar target/lizzie-0.7.4-shaded.jar

(or whatever the current version of the shaded `jar` file is in
`target/`).

After you run this command you should see a GUI start. Lizzie will also start a Leela Zero
process that it will communicate with. You can configure the location of Leela Zero from the
`config.txt` file from the folder you started the `java` command. If Lizzie is unable to start
Leela Zero it will display an error and you can fiddle with the `config.txt` file
until you get all the paths correct.

## Usage tips

Lizzie provides a multitude of options to load and save SGF files, run an auto analysis and
configure the board. To see all the options just hold down the key **x** (yes, just press and hold
the letter **x**) and you will see all the commands listed in the GUI.

## Contributing

Pull requests are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md)
for details. The CI pipeline runs `mvn clean package` on Linux, macOS
and Windows against JDK 11, 17 and 21, and also enforces formatting via
`mvn com.coveo:fmt-maven-plugin:check`. You can apply formatting locally
with:

    $ mvn com.coveo:fmt-maven-plugin:format
