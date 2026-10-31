# Screen map

Design files are the `.dc.html` artboards in this folder; tokens are in `hired.css`. The design wins on visuals and layout, the brief wins on features and behaviour.

| Design | Route | Module | Key widgets |
|---|---|---|---|
| B01 Splash | `/splash` | shell | logo mark |
| B02 Onboarding 1 | `/onboarding/1` | shell | TickDial (small), floating glass chips, PrimaryButton |
| B03 Onboarding 2 | `/onboarding/2` | shell | weights bar, PrimaryButton |
| B04 Permissions | `/onboarding/3` | shell | permission rows, switches |
| B05 Sign in | `/sign-in` | auth | PrimaryButton, OutlineButton, field |
| B06 Profile setup | `/profile-setup` | auth | chips, field |
| A01 Home / A09 After / B07 Light | `/home` | M1 | TickDial, ScoreCorner, NextActionCard, tab shell |
| A02 Resume input | `/resume` | M2, M3 | file row, JD field, PrimaryButton |
| A03 Analysing | `/resume/analysing` | M3 | staged steps, scanner |
| A04 Match result | `/resume/result` | M3 | gauge, score components, keyword chips, fix list |
| A05 Bullet rewrite | `/resume/rewrite` | M4 | segmented tabs, diff text, bottom sheet |
| A06 Interview setup | `/interview` | M7 | selectors, project list |
| A07 Interview live | `/interview/live` | M7 | Orb, wave, metric tiles, camera preview |
| A08 Report | `/interview/report/:id` | M7 | rubric dots, pace and eye chart, fix list |
| C01 Intro recorder | `/intro` | M6 | 60-tick countdown, transcript |
| C02 Intro result | `/intro/result` | M6 | score, before and after |
| C03 Presence camera | `/presence` | M5 | camera, occasion segment |
| C04 Presence result | `/presence/result` | M5 | breakdown bars, fixes |
| C05 Tracker / C06 Empty | `/tracker` | M8 | stage filters, application tile |
| C07 Progress / C08 Empty | `/progress` | M10 | line chart, streak, badges |
| A10 Scorecard | `/progress/scorecard` | M10 | 1080x1920 RepaintBoundary card |
| C09 Pro | `/pro` | concept | pricing, coming-soon sheet |
| C10 Settings | `/settings` | all | theme segment, switches, hidden demo-mode tap |

## Brief features with no designed screen (need design before or while building)
1. **Company Mode brief** on interview setup: summary, interview style, recent news, sources (M7).
2. **Language selector** English / Hinglish on interview setup (M7).
3. **Coach Replay** screen: video/audio, scrubbable marker timeline, synced transcript, marker notes (M7). Biggest gap, it is the second wow moment.
4. **Evidence view**: tap any score to see the transcript line, resume bullet or metric behind it (all modules).
5. **Multi-JD compare**: up to 3 JDs side by side (M3).
6. **Parsed resume editor** and **resume PDF export** preview (M2, M4).
7. **Kanban board** with drag and drop (M8). Only the list view is designed.
8. **Application detail** with "Run Resume Match" and "Practise interview for this company" actions (M8).
9. **Add application** with paste-JD autofill (M8).
10. **Intro comparison** with the previous attempt (M6).
11. **Presence live framing guide** overlay states (M5).
12. **Badges and best-ever stats** detail (M10).
13. **Reminder notification** content and deep links (M9).
14. **Landing page** (`web/`) is not designed.

## Designed screens not in the brief
- Splash, three onboarding pages, sign-in and profile setup are designed; the brief only mentions Auth. Kept, they are cheap and make the demo feel finished.
- Light mode (B07) is designed for Home only; the brief says ColorScheme light + dark, so every other screen needs a light pass.

## Conflict to resolve
- The brief says readiness uses **gentle time decay**. The design and the demo story (62 to 68) assume no decay. I will implement decay as a function with a long half-life (default none within 21 days) so the demo numbers hold. Tell me if you want different behaviour.
