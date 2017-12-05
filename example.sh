#!/bin/bash
source="/Users/ivo/Dropbox/web/hue/"
dest="ccu:'/usr/local/scripts/hue/'"
remote=1

if [ $remote == 1 ]; then
	rsync -av  --prune-empty-dirs --delete --exclude=.Spotlight-V100 --exclude=Parallels --exclude=.DocumentRevisions-V100 --exclude=.DS_Store --exclude=.Trash*/ --exclude=.TemporaryItems/ --exclude=.fseventsd/ --exclude=Backups.backupdb/ --filter="P .Spotlight-V100/" --filter="P .DocumentRevisions-V100/" --filter="P .fseventsd/" --filter="P .TemporaryItems/" --exclude=tmbootpicker.efi --exclude=*~ \
	"$source" "$dest" > /dev/null
	ssh ccu "/usr/local/scripts/hue/ccu_read_hue.tcl"
else
	~/Dropbox/web/hue/test.tcl
fi
