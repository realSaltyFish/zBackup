# zBackup

A lightweight ZFS backup tool.

## Introduction

zBackup is a bash script that helps you backup your ZFS datasets. With the help of zBackup, it becomes easier to automate your backup process.

> Disclaimer: zBackup is a personal project developed by an amateur college student. It is **not** guaranteed to work correctly. Use at your own risk.

Currently, zBackup can create snapshots, export snapshots, upload exported files and clean old snapshots. During a single run, these tasks (if enabled) will be performed in the listed order.

## Building

Use the `build.sh` script to build zBackup. Currently the script lacks error checking mechanism. You are suggested to check its contents before executing it. The script generates the final product `build/zbackup.sh`.

## Requirements

To use zBackup, you need to make sure that you have correctly setup ZFS and granted all permissions required to the user you are running zBackup with. These permissions include: `snapshot`, `mount`, `send` and `destroy`. Note that `mount` is not directly used. Rather, it is a prerequisite for  `destroy`.

Please make sure that the place you specify for storing exported backups is accessible for zBackup.

To use the upload feature, you will have to install `rclone`.

## Specifying datasets to process

zBackup accepts two methods to specify the datasets that should be processed during a single run.

### Using the `-p` flag

`-p` should be followed by a pool to specify all datasets in this pool. Note that in the current stage, only one pool should be specified. If you need to backup multiple pools, consider using the `-f` flag or running zBackup multiple times.

When using this mode, zBackup reads the ZFS property `zbackup:enabled` to determine if a dataset should be taken care of. Please set this property to `true` for datasets you wish to backup with zBackup. Any dataset with this property unset or set to other values will be ignored in this mode. However, if you use the `-f` flag, this property is ignored.

### Using the `-f` flag

`-f` can be followed by one or more datasets. These datasets will be processed regardless of their values of the property `zbackup:enabled`. Invalid datasets will be ignored.

Note that `-f` takes precedence over `-p`. If you use them together, `-p` will be ignored.

## Specifying a date

Assuming that you will not backup several times during a day, zBackup uses the date as the identifier of a backup. The date is in the format `YYYYmmdd`. By default, zBackup gets the current date automatically. However, if you want to work on a previous backup, you can use the flag `--date` to specify a date.

### Dry runs

zBackup allows you to preview the changes it is about to make before actually performing the tasks. Use the flag `-d` to tell zBackup to perform a dry run. The output will look as if it were an ordinary run, but no change will be made to your datasets and no file will be produced.

## Creating snapshots

Use the flag `-s` to tell zBackup to create snapshots for specified datasets.

## Exporting (sending) snapshots

Use the flag `-e` to tell zBackup to export specified snapshots as files. You need to specify where these files should be stored using the `-t` flag.

zBackup uses `gzip` to compress the exported contents and uses `split` to split the backup into 10GB files.

> Example: `zbackup.sh --date 20201231 -f pool/fs -t ~/backups -e` will export the snapshot `pool/fs@20201231` to `~/backups/pool/fs/20201231/`. Supposing that the snapshot is 25GB large, these files will be created: `backup.zfs.gz_part00`(10GB), `backup.zfs.gz_part01`(10GB),`backup.zfs.gz_part02`(5GB).

Currently, zBackup cannot restore the backup for you. You may manually concatenate these files, decompress them and use `zfs receive` to restore it.

zBackup calls `zfs send` with the `-w` flag so that encrypted datasets will be exported encrypted. There should be no need to disable this feature.

> Warning: Please make sure that you do not store other files in the target directory. Otherwise your files may get overwritten.

## Uploading exported snapshots

Use the `-u` flag to tell zBackup to upload the files created using `-e` to your cloud storage. zBackup calls `rclone` for this functionality. `-u` should be followed by a `rclone`-style address, e.g. `clouddisk:some/dir`. `-t` should be used to tell zBackup where to look for the files to upload. The value should be exactly the same as when you used `-e` to export the snapshot. `-e` and `-u` can be used together.

## Cleaning old snapshots

zBackup can help you clean the snapshots following your policy. Use the `-c` flag followed by a policy to use this feature. Note that the exported files will **NOT** be deleted. Only the snapshots themselves will be destroyed. Currently two types of policies are supported.

1. `keep`: Destroys all snapshots except the most recent ones. For example, `keep5` keeps the latest 5 snapshots only.

2. `before`: Destroys all snapshots before the specified date. For example, `before20201231` destroys `pool/fs@20201230` and `pool/fs@20201125`, but not `pool/fs@20201231` and `pool/fs@20210102`.

### Confirmation

As this operation can be dangerous, confirmation is required. If you are using zBackup as a cron task (or in any other situation where manual confirmation would be inconvenient), you can use the flag `-y` to automatically confirm the operation.
