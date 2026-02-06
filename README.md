# rcal

A fast, pure Ruby command-line interface for Google Calendar.

## Features

- **Natural language dates** - "tomorrow 3pm", "next monday", "friday noon"
- **Event management** - create, edit, and view events
- **ICS import** - import calendar invites from .ics files
- **Predicate filtering** - filter by recurring, one-on-one, declined, etc.
- **Multiple calendars** - work with any calendar in your account
- **Fast startup** - built with cli-kit for snappy performance

## Installation

```bash
git clone https://github.com/yourusername/rcal.git
cd rcal
bundle install
```

## Setup

1. Create OAuth credentials in [Google Cloud Console](https://console.cloud.google.com/apis/credentials):
   - Create a new project (or use existing)
   - Enable the Google Calendar API
   - Create OAuth 2.0 Client ID (Desktop app type)
   - Note your Client ID and Client Secret

2. Authenticate rcal:

```bash
rcal init --client-id=YOUR_CLIENT_ID --client-secret=YOUR_CLIENT_SECRET
```

## Usage

### View Events

```bash
# Today's agenda
rcal agenda

# Tomorrow
rcal agenda tomorrow

# Next 7 days
rcal agenda --days=7

# Specific date range
rcal agenda "next monday" "next friday"

# Filter by predicates
rcal agenda --must-be=recurring
rcal agenda --must-not-be=declined,all_day

# Show event IDs (for editing)
rcal agenda --show-ids
```

### Create Events

```bash
# Quick add with natural language
rcal quick "Lunch with Sarah tomorrow noon"
rcal quick "Team standup every weekday 10am"

# Structured add
rcal add --title="Team Meeting" --when="tomorrow 3pm"
rcal add --title="Lunch" --when="friday noon" --duration=1h30m --location="Cafe"
rcal add --title="Vacation" --when="monday" --all-day
```

### Edit Events

```bash
# Get event ID from agenda
rcal agenda --show-ids

# Edit event
rcal edit EVENT_ID --title="Updated Title"
rcal edit EVENT_ID --when="tomorrow 4pm" --duration=30m
rcal edit EVENT_ID --location="Room 202"
```

### Import ICS Files

```bash
# Import calendar invite
rcal import ~/Downloads/invite.ics

# Import to specific calendar
rcal import meeting.ics --calendar=work@company.com
```

### List Calendars

```bash
rcal list
```

## Available Predicates

Use with `--must-be` and `--must-not-be` flags:

| Predicate | Description |
|-----------|-------------|
| `accepted` | Events you've accepted |
| `declined` | Events you've declined |
| `awaiting` | Events awaiting your response |
| `tentative` | Events you've tentatively accepted |
| `all_day` | All-day events |
| `recurring` | Recurring events |
| `one_on_one` | Events with exactly 2 attendees |
| `busy` | Events that block your calendar |
| `commitment` | Events with 2+ attendees you haven't declined |

## Duration Formats

- `30m` - 30 minutes
- `1h` - 1 hour
- `1h30m` - 1 hour 30 minutes
- `1.5h` - 1.5 hours (90 minutes)
- `2h15m` - 2 hours 15 minutes

## Configuration

rcal follows XDG Base Directory specification:

- Config: `~/.config/rcal/`
- Data: `~/.local/share/rcal/`

## Development

```bash
# Run all tests and linter
bundle exec rake

# Run all tests
bundle exec rake test

# Run unit tests only
bundle exec rake test:unit

# Run linter
bundle exec rake lint

# Run linter with auto-fix
bundle exec rake lint:fix

# List all available tasks
bundle exec rake -T

# Run CLI locally
./exe/rcal help
```

## Architecture

rcal uses an adapter pattern for all external dependencies:

```
Rcal::DateParser      -> Rcal::Adapters::DateParser::Chronic
Rcal::DurationParser  -> Rcal::Adapters::DurationParser::ChronicDuration
Rcal::IcsParser       -> Rcal::Adapters::IcsParser::Icalendar
Rcal::CalendarService -> Rcal::Adapters::Calendar::Google
Rcal::Auth            -> Rcal::Adapters::Auth::Google
```

This allows swapping implementations without changing application code.

## License

MIT
