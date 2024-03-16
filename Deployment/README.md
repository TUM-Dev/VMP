# VMP Debian RootFS

This subdirectory contains the scripts and configuration files to build a Debian
root filesystem with the complete VMP stack installed.

We use [rootfsbuilder](https://github.com/hmelder/rootfsbuilder) to build the
root filesystem. By default, a squashfs image is created, but it is also possible
to create a tarball by adding `"tarball_type": "tar.gz"` to the JSON configuration.

## Building the root filesystem

Obtain the `rootfsbuilder` tool by building it from source. More
information about the tool and the build process can be found in the
projects README.
After that, run the following command to build the root filesystem:

```bash
sudo ./setup.sh # This will create payload.tar
sudo rootfsbuilder bookworm-amd64.json
```

The payload contains a post install script that builds the Objective-C environment (libobjc2, libdispatch (Grand Central Dispatch), gnustep-base (Foundation)). If everything goes well, you now have a squashfs image in
the current working directory.

## Customizing the root filesystem

You can add additional files to the root filesystem by adding them to the
payload directory. The files will be copied to the root filesystem during the
build process.

If you want to change the release or distribution, you can modify the
build configuration JSON file.
