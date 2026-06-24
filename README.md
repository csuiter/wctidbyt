# World Cup — Tidbyt app

A [Tidbyt](https://tidbyt.com) / [Pixlet](https://tidbyt.dev) app that tracks **live FIFA
World Cup scores** on the 64×32 display.

It shows in-progress matches first (cycling through all of them), then today's upcoming
matches, then the most recent finals. Each match is drawn with both teams' logos, the
score, and a status line — a live clock for in-play games, the kickoff time for upcoming
games, or the final result.

Data comes from ESPN's public scoreboard API. **No API key required.**

## Repository layout

The app is packaged in the [tidbyt/community](https://github.com/tidbyt/community)
directory layout, so it can be dropped straight into that repo:

```
apps/worldcup/
├── worldcup.star     # the Pixlet app
└── manifest.yaml     # app metadata (id, name, summary, author)
```

## Display

```
   LIVE 67'          <- status: live clock / kickoff time / "FT"
[🇧🇷] 2-1 [🇦🇷]      <- home logo · score · away logo
 BRA      ARG        <- team abbreviations
```

When more than one match qualifies, the app cycles through them (~4.5s each).

## Install Pixlet

Pixlet is the Tidbyt app runtime/CLI. Install it, then use it to preview and push the app.

```sh
# macOS
brew install tidbyt/tidbyt/pixlet
```

For Linux/Windows or manual installs, see the
[Pixlet installation docs](https://tidbyt.dev/docs/build/installing-pixlet).

## Preview locally

```sh
pixlet serve apps/worldcup/worldcup.star
```

Open <http://localhost:8080> to see a live render. The config options (below) appear in
the serve UI so you can try them without editing code.

## Render & push to a device

```sh
pixlet render apps/worldcup/worldcup.star
pixlet push <DEVICE_ID> worldcup.webp        # one-off push
# or install it so the device rotates it automatically:
pixlet push --installation-id worldcup <DEVICE_ID> worldcup.webp
```

Find your `<DEVICE_ID>` and API token via the Tidbyt mobile app
(Settings → General → Get API Key / Device ID), or with `pixlet devices`.

## Configuration

| Option              | Description                                                           |
| ------------------- | --------------------------------------------------------------------- |
| Live matches only   | Show only matches that are currently in progress.                     |
| Time format         | 24-hour or 12-hour (AM/PM) for upcoming-match kickoff times.          |
| Favorite team       | Pull this team's match to the front of the rotation.                  |
| Timezone            | Localizes kickoff times for upcoming matches (defaults to device tz). |

## Notes

- **Data source:** `https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard`
  (ESPN's public, undocumented scoreboard endpoint — the same source used by many Tidbyt
  community sports apps). Scores are cached for 60 seconds; team logos for 24 hours.
- **Other competitions:** change the `COMPETITION` constant at the top of `apps/worldcup/worldcup.star`
  (e.g. `fifa.cwc` for the FIFA Club World Cup).
