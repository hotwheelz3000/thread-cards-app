# Thread Cards

An iPhone app that turns a Threads post into two story-size images (1080 x 1920), styled like the Threads "Add to Instagram story" card, with the **full** post text split across them (1/2 and 2/2).

## Use

1. In Threads, tap Share > Copy link on a post.
2. In Thread Cards, tap **Paste & Get**. The app reads the post: name, checkmark, picture, text, time and counts.
3. Check the two previews, then tap **Save to Photos**.

If the post can't be read, open **Edit post** and type or paste the text. Every field there can be changed before saving.

## Download

Every push to `main` builds an unsigned IPA and publishes it as the `latest` release:

```
https://github.com/hotwheelz3000/thread-cards-app/releases/latest
```

Sign it when installing (Signulous, Sideloadly or AltStore).

## Build

Built with [xtool](https://xtool.sh) (SwiftPM, no Xcode project) on GitHub Actions. The version is in `ThreadCards-Info.plist`; release notes are in `RELEASE_NOTES.md`.

Not affiliated with Threads or Meta.
