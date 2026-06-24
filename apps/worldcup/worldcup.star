"""
World Cup — live FIFA World Cup scores for Tidbyt.

Shows in-progress matches first (cycling through all of them), then today's
upcoming matches, then the most recent finals. Each match is drawn with both
teams' logos, the score, and a status line (live clock, kickoff time, or FT).

Data comes from ESPN's public, key-less scoreboard API — the same source used
by many Tidbyt community sports apps. No API key required.
"""

load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

# ESPN hidden scoreboard API. The slug controls the competition:
#   fifa.world -> FIFA World Cup (men's national teams)
#   fifa.cwc   -> FIFA Club World Cup
# Change COMPETITION to repoint the app at a different tournament.
COMPETITION = "fifa.world"
ESPN_URL = "https://site.api.espn.com/apis/site/v2/sports/soccer/{}/scoreboard".format(COMPETITION)

# Caching: scores refresh ~once a minute; logos effectively never change.
SCORE_TTL = 60
LOGO_TTL = 86400

# How many matches to cycle through, to bound render size.
MAX_MATCHES = 4

# Animation hold: render.Root runs at `delay` ms/frame. Repeating each match
# panel HOLD_FRAMES times holds it on screen for HOLD_FRAMES * delay ms.
FRAME_DELAY_MS = 100
HOLD_FRAMES = 35  # ~3.5s per match

# Tidbyt caps an app's animation at ~15 seconds (150 frames at 100ms). Keep the
# total cycle within budget regardless of how many matches qualify.
MAX_TOTAL_FRAMES = 150

WHITE = "#ffffff"
GREY = "#9a9a9a"
LIVE_GREEN = "#36d147"
SCORE_YELLOW = "#f6c945"

DEFAULT_TZ = "UTC"

def main(config):
    resp = http.get(ESPN_URL, ttl_seconds = SCORE_TTL)
    if resp.status_code != 200:
        return render.Root(child = _message("No World Cup data"))

    data = resp.json()
    events = data.get("events", [])

    matches = [_parse_match(e) for e in events]
    matches = [m for m in matches if m != None]

    if config.bool("live_only", False):
        matches = [m for m in matches if m["state"] == "in"]

    matches = _order_matches(matches, config.str("team", ""))

    if len(matches) == 0:
        return render.Root(child = _message("No matches"))

    matches = matches[:MAX_MATCHES]

    tz = _get_tz(config)
    use_24h = config.str("time_format", "24h") == "24h"

    panels = [_render_match(m, tz, use_24h) for m in matches]

    if len(panels) == 1:
        return render.Root(child = panels[0])

    # Stay within Tidbyt's animation-length budget.
    max_panels = MAX_TOTAL_FRAMES // HOLD_FRAMES
    if len(panels) > max_panels:
        panels = panels[:max_panels]

    # Hold each panel on screen by repeating it across many animation frames.
    frames = []
    for panel in panels:
        for _ in range(HOLD_FRAMES):
            frames.append(panel)

    return render.Root(
        delay = FRAME_DELAY_MS,
        child = render.Animation(children = frames),
    )

def _get_tz(config):
    """Resolve the timezone from the Location field, else the device tz, else UTC."""
    loc = config.get("timezone")
    if loc:
        parsed = json.decode(loc)
        tz = parsed.get("timezone", "")
        if tz:
            return tz
    return config.get("$tz") or DEFAULT_TZ

def _parse_match(event):
    """Normalize an ESPN event into a flat match dict, or None if malformed."""
    comps = event.get("competitions", [])
    if len(comps) == 0:
        return None
    comp = comps[0]

    competitors = comp.get("competitors", [])
    home = None
    away = None
    for c in competitors:
        if c.get("homeAway") == "home":
            home = c
        elif c.get("homeAway") == "away":
            away = c

    # Fall back to positional order if homeAway is missing.
    if home == None or away == None:
        if len(competitors) != 2:
            return None
        home = home or competitors[0]
        away = away or competitors[1]

    status = comp.get("status", event.get("status", {}))
    state = status.get("type", {}).get("state", "pre")
    detail = status.get("type", {}).get("shortDetail", "")
    clock = status.get("displayClock", "")

    return {
        "home_abbr": _abbr(home),
        "away_abbr": _abbr(away),
        "home_score": home.get("score", "0"),
        "away_score": away.get("score", "0"),
        "home_logo": home.get("team", {}).get("logo", ""),
        "away_logo": away.get("team", {}).get("logo", ""),
        "state": state,
        "clock": clock,
        "detail": detail,
        "date": event.get("date", ""),
    }

def _abbr(competitor):
    team = competitor.get("team", {})
    return team.get("abbreviation") or team.get("shortDisplayName") or "?"

def _order_matches(matches, fav):
    """Live first, then upcoming (soonest), then finals (most recent)."""
    live = [m for m in matches if m["state"] == "in"]
    pre = [m for m in matches if m["state"] == "pre"]
    post = [m for m in matches if m["state"] not in ("in", "pre")]

    pre = sorted(pre, key = lambda m: m["date"])
    post = sorted(post, key = lambda m: m["date"], reverse = True)

    ordered = live + pre + post

    # Pull the favorite team's match to the front, if present.
    if fav:
        fav_matches = [m for m in ordered if fav in (m["home_abbr"], m["away_abbr"])]
        others = [m for m in ordered if fav not in (m["home_abbr"], m["away_abbr"])]
        ordered = fav_matches + others

    return ordered

def _render_match(m, tz, use_24h):
    return render.Column(
        expanded = True,
        main_align = "space_between",
        cross_align = "center",
        children = [
            _status_line(m, tz, use_24h),
            render.Row(
                expanded = True,
                main_align = "space_evenly",
                cross_align = "center",
                children = [
                    _logo(m["home_logo"], m["home_abbr"]),
                    render.Text(
                        content = "%s-%s" % (m["home_score"], m["away_score"]),
                        font = "6x13",
                        color = SCORE_YELLOW,
                    ),
                    _logo(m["away_logo"], m["away_abbr"]),
                ],
            ),
            render.Row(
                expanded = True,
                main_align = "space_evenly",
                children = [
                    render.Text(content = m["home_abbr"], font = "tom-thumb", color = GREY),
                    render.Text(content = m["away_abbr"], font = "tom-thumb", color = GREY),
                ],
            ),
        ],
    )

def _status_line(m, tz, use_24h):
    if m["state"] == "in":
        label = ("LIVE " + m["clock"]).strip()
        color = LIVE_GREEN
    elif m["state"] == "pre":
        label = _kickoff(m["date"], tz, use_24h)
        color = WHITE
    else:
        label = m["detail"] or "FT"
        color = GREY

    text = render.Text(content = label, font = "tom-thumb", color = color)

    # Scroll the label if it would overflow the 64px display.
    if len(label) > 12:
        return render.Marquee(width = 64, child = text)
    return text

def _kickoff(iso, tz, use_24h):
    if not iso:
        return "TBD"

    # ESPN returns RFC3339 usually without seconds ("2026-06-11T16:00Z"), but
    # occasionally with them. time.parse_time errors on a format mismatch, so
    # pick the layout to match. "Z07:00" handles both "Z" and "+hh:mm" offsets.
    if iso.count(":") >= 2:
        in_fmt = "2006-01-02T15:04:05Z07:00"
    else:
        in_fmt = "2006-01-02T15:04Z07:00"

    parsed = time.parse_time(iso, format = in_fmt)
    local = parsed.in_location(tz)
    out_fmt = "15:04" if use_24h else "3:04 PM"
    return local.format(out_fmt)

def _logo(url, fallback):
    if url:
        resp = http.get(url, ttl_seconds = LOGO_TTL)
        if resp.status_code == 200:
            return render.Image(src = resp.body(), width = 16, height = 16)

    # No logo available — show the abbreviation in a box instead.
    return render.Box(
        width = 16,
        height = 16,
        child = render.Text(content = fallback, font = "tom-thumb", color = WHITE),
    )

def _message(text):
    return render.Box(
        child = render.WrappedText(
            content = text,
            font = "tom-thumb",
            color = GREY,
            align = "center",
        ),
    )

# Static list of the 48 FIFA World Cup 2026 team abbreviations (ESPN codes),
# used to populate the optional "favorite team" dropdown.
WC_TEAMS = [
    "ARG", "AUS", "AUT", "BEL", "BRA", "CAN", "CIV", "COL", "CPV", "CRO",
    "ECU", "EGY", "ENG", "ESP", "FRA", "GER", "GHA", "HAI", "IRN", "ITA",
    "JOR", "JPN", "KOR", "KSA", "MAR", "MEX", "NED", "NGA", "NOR", "NZL",
    "PAN", "PAR", "POR", "QAT", "RSA", "SCO", "SEN", "SUI", "TUN", "URU",
    "USA", "UZB", "WAL",
]

def get_schema():
    team_options = [schema.Option(display = "(none)", value = "")] + [
        schema.Option(display = abbr, value = abbr)
        for abbr in WC_TEAMS
    ]

    return schema.Schema(
        version = "1",
        fields = [
            schema.Toggle(
                id = "live_only",
                name = "Live matches only",
                desc = "Only show matches that are currently in progress.",
                icon = "futbol",
                default = False,
            ),
            schema.Dropdown(
                id = "time_format",
                name = "Time format",
                desc = "How kickoff times for upcoming matches are shown.",
                icon = "clock",
                default = "24h",
                options = [
                    schema.Option(display = "24-hour", value = "24h"),
                    schema.Option(display = "12-hour (AM/PM)", value = "12h"),
                ],
            ),
            schema.Dropdown(
                id = "team",
                name = "Favorite team",
                desc = "Pull this team's match to the front of the rotation.",
                icon = "star",
                default = "",
                options = team_options,
            ),
            schema.Location(
                id = "timezone",
                name = "Timezone",
                desc = "Used to localize kickoff times for upcoming matches.",
                icon = "locationDot",
            ),
        ],
    )
