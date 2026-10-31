# Numeric settings persistence

The native settings UI previously used a formatted value TextField, which could defer its binding write until Return or focus loss even though the UI promised automatic saving. Quitting while bandwidth was being edited could lose the value. Discovery also received SIGTERM during shutdown before queued saves had drained.

Numeric fields now send every complete in-range integer from AppKit's editing notification. Incomplete/out-of-range drafts remain local, and engine acknowledgments do not overwrite the active field/caret. Units remain Kbps. The existing bridge and QSettings keys are unchanged; changing FPS/resolution still uses stock automatic bitrate adjustment when enabled.

Discovery shutdown uses its existing ordered JSON shutdown command after pending settings. Actual application termination keeps the stdout reader alive for up to two seconds, allowing final saves and acknowledgments to drain before frontend pipes close. Its exit semaphore is signaled on the reader queue, not MainActor. Normal store shutdown and stream termination remain nonblocking. A stalled discovery helper is terminated at the deadline.

Validation: the numeric editor test compiles the production editor and exercises before-blur autosave, invalid drafts and range changes. SettingsPersistenceTests starts real frontend/helper processes, checks restart and next-stream configuration, then verifies several queued edits survive actual frontend-process exit. bridge_smoke.py exercises the packaged Qt helper, QSettings restart persistence and automatic/manual bitrate semantics. No unrelated preferences or core settings algorithms change.
