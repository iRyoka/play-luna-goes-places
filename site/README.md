# Public landing page

This directory is the committed source for the Luna Goes Places landing page.
It contains no generated Web export, APK, credentials, or feedback-provider
configuration. It includes English and Russian copy, with a browser-language
default and a locally remembered visitor choice.

The private publication workflow copies this directory into an isolated Pages
staging tree, unpacks the matching versioned Web archive under `play/`, and writes
the public `site-config.js` file. That generated file supplies the versioned APK,
source, and notices URLs. The Formspree form endpoint is deliberately present in
`index.html`: it is public configuration, not a credential. `site-config.example.js`
is only a non-working public-value example for local review.

The deployed page must always be prepared from the same accepted version as the
public repository's `main`, GitHub Release, and Web build. Do not commit generated
Web payloads or a real deployment configuration here.

`release-notes.js` holds the bilingual player-facing notes in newest-first order.
Before publishing a new version, add its entry with the exact `version` from
`version.txt` and short `en` and `ru` paragraph arrays. The home page shows the
entry matching the deployed version; `changelog.html` lists all entries. Do not
add a note for a release whose actual content has not been accepted. If a release
uses a picture, add only approved public-safe art and a text alternative. The
Windows URL is generated from the release manifest by `prepare_pages.ps1`; it
must match the version shown on the page.
