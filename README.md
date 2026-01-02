# cdj3k-magicphono-loader

Magic Phono on your CDJ-3000.

## Why?

Allows booting of custom firmwares from an SD-card.

The update file toggles a boot flag in non-volatile memory to allow booting firmware from an SD-card.

If no bootable SD-card is present the CDJ-3000 will continue booting from internal firmware as usual.

The chances of this bricking your CDJ-3000 is low as it does not update or overwrite the firmware in the CDJ,
however there is a non-zero chance something could go wrong.

> [!CAUTION]
> This tool is experimental software with the potential to brick your CDJ. **USE AT YOUR OWN RISK**.


## Quick guide

- Download the pre-built <a href="https://github.com/Magic-Phono/cdj3k-magicphono-loader/releases/download/v1.0.0/CDJ3KvSDBOOT001.UPD">`CDJ3KvSDBOOT001.UPD`</a> update file.
- Copy it to a FAT32 USB key. Make sure there are no other update files on the USB key.
- Insert the USB key into your CDJ-3000. Enter udpate mode by pressing IN/CUE and RELOOP/EXIT while powering on the unit.
- Once complete, you can reboot your CDJ.
- Congratulations! You can now boot custom firmwares from an SD-card.

# Uninstall

TODO

## Building from source

To build from source, you will need to acquire a valid firmware encryption key.
Instructions to do this are not provided here. Once you have the key, save it to `aes256.key` in the repo root.

To build:
```
./make_firmware.sh build <target>
```

To clean:
```
./make_firmware.sh clean <target>
```

Where `<target>` is one of:
- `loader`: Legacy `check_apl_mode` style loader (do not use).
- `sdboot`: Update boot flag to allow booting firmware from an SD-card.


## License

`cdj3k-magicphono-loader` is based on `cdj3k-root`.
cdj3k-root uses the MIT License. The project contains no Pioneer DJ/AlphaTheta code.
