### Delete folders in subfolders
This will delete all folders in subfolders
```bash
find . -type d \( -name ".idea" -o -name "jars" -o -name ".gradle" -o -name "build" -o -name ".kotlin" \) -exec rm -rf {} +
```

Fast zip
```bash
DIR=SAMPLE_FOLDER && tar -cf - "$DIR" | pv -s $(du -cb "$DIR" | tail -1 | awk '{print $1}') | pigz -9 -p 32 > $DIR-backup-$(date +%-Y%-m%-d)-$(date +%-T).tar.gz;
```