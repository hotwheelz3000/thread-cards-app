# Threads Cards

An iPhone app that turns a Threads post into story-size images (1080 x 1920) that look like the Threads "Add to Instagram story" card, but with the **full** text, and saves them to Photos.

## Use

1. In Threads, tap Share > Copy link on a post.
2. In Threads Cards, tap **Paste & Get**.
3. Check the previews, then tap **Save to Photos**. If the post has a video, **Save Video** saves it too.

## What you get

- **Threads:** when the author continued the post in a thread, each of their posts gets its own card (1/2, 2/2...), like Threads.
- **Replies:** paste a reply's link and the post it answers comes first, each card with its own name, picture and checkmark.
- **Long posts:** the text stays the same size; a post too long for one card continues on the next, breaking at the end of a sentence. The pills count every card (1/3, 2/3, 3/3).
- **Short posts:** one card, no pill.
- **History** (clock button, top right): every post you get is kept. Tap one to bring it back, swipe left to delete.
- **Edit post:** every field can be changed before saving, including the original post and the thread's next posts. If a post can't be read, type or paste the text here.

## Download

Every push to `main` builds an unsigned IPA and publishes it as the `latest` release:

```
https://github.com/hotwheelz3000/thread-cards-app/releases/latest
```

Sign it when installing (Signulous, Sideloadly or AltStore).

## Code

Built with [xtool](https://xtool.sh) (SwiftPM, no Xcode project) on GitHub Actions. Sources are in `Sources/ThreadCards/`:

- `Cards/`: the post data, the card view (Threads look) and `Paginator` (spreads long posts over cards)
- `Fetching/`: `PostFetcher` (reads a post page), `PageReader` (opens the page in a hidden web view for videos, the thread's next posts and the post being replied to), `Savers` (Photos)
- `History/`: saved posts (`history.json` in the app's Documents folder) and the History screen
- `Screens/`: the main screen and Edit post
- `Theme/`: the Soulection style for the app's screens (Bai Jamjuree font in `Resources/Fonts`, SIL Open Font License)

The version is in `ThreadCards-Info.plist`; release notes are in `RELEASE_NOTES.md`.

Not affiliated with Threads or Meta.

## Updates

- **Update feed:** each release also has `source.json`, an AltStore-format source. Add this URL in a sideloading app that supports sources to see new builds as updates:

```
https://github.com/hotwheelz3000/thread-cards-app/releases/download/latest/source.json
```

## Checks before each build

- **JavaScript check:** `scripts/check-js.py` runs `node --check` on every script held in a Swift multi-line string. A syntax error stops the build and points at the Swift file and line.
- **Dependabot:** `.github/dependabot.yml` opens a pull request each week when the build's GitHub Actions have updates. Merge it to update.
