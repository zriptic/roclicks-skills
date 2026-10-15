# Roblox video specs (researched 2026-10-11)

Two Roblox features take uploaded video, and they publish different amounts of detail. The trailer
targets the **experience video thumbnail** (it plays first on the game's detail page and can show on Home).
Roblox's thumbnail page lists no file specs for it, so edit.py and qa.py use the published limits of
Roblox's general video uploads as the safe target.

## Experience video thumbnail (detail page). Source: Creator Hub, Thumbnails
https://create.roblox.com/docs/production/publishing/thumbnails

| Item | Confirmed value |
|---|---|
| Cost / quota | Free, **3 uploads per month**. Rejected videos still use up quota. |
| Slots | Up to 10 images or videos per detail page; an approved video shows first. |
| Where | Creator Dashboard > Configure > Places > (place) > Videos (older doc path: Thumbnails) |
| Platforms | Not shown on Xbox, PlayStation or VR headsets |
| Content | Must be **authentic gameplay**. Allowed edits: varied camera angles, minor post-processing, curated highlight sequences, in-game UI text, a game logo overlay. |
| Not allowed | Gameplay or features the game doesn't have, artificially enhanced graphics, real-life or external footage, **text claims or ads** (e.g. "50% off") |
| Audio | Music from Roblox's catalog is allowed. **No voice-over, narration, voice chat or music with lyrics.** |
| Length / resolution / size / format | **Not published on this page.** |

## Video uploads (VideoFrame assets). Source: DevForum announcement + Creator Hub
https://devforum.roblox.com/t/2630621 ("Video uploads [Beta]")
https://create.roblox.com/docs/ui/video-frames

| Item | Value | Source |
|---|---|---|
| Length | **30 s or less** (beta announcement); the current VideoFrame doc says 5 min or less | DevForum / Creator Hub |
| Format | **.mp4 or .mov** | both |
| Max resolution | **4096x2160**; minimum 160x160; width and height divisible by 2 | both |
| Recommended | **1920x1080 at 60 fps** (VideoFrames never display above 720p) | DevForum |
| File size | **375 MB** (beta); the current VideoFrame doc says 3.75 GB | DevForum / Creator Hub |
| Audio | 0 or 1 audio track; any speech/text in English and/or Spanish | DevForum |
| Account | 13+ and **ID-verified** | both |
| Cost | 2,000 Robux per upload (VideoFrame assets) | both |
| Other | No alpha channel; copyright detection applies | both |

An older DevForum request ("Longer Video Thumbnails", devforum.roblox.com/t/61181) also cites a
30-second cap for video thumbnails. It's community-sourced, not an official statement.

## What the scripts enforce for the `roblox` cut
- At most **30.0 s**, **1920x1080**, H.264 High, yuv420p, **60 fps**, AAC 48 kHz (one track), .mp4 with faststart. That stays under 375 MB by a wide margin; a 30 s cut is about 35 MB.
- Leave out `social_only` cards. A "Play free on Roblox" call to action is fine on YouTube or TikTok, but on Roblox it reads as an ad or claim, so the Roblox cut ends on the title or logo card.
- Music must be Roblox-catalog or properly licensed, and instrumental (no lyrics). No narration.
- Every staged outcome must be possible in the real game (see "Honesty" in SKILL.md).

The upload dialog is the final authority. If it rejects a file, record the dialog's numbers here with the date.
