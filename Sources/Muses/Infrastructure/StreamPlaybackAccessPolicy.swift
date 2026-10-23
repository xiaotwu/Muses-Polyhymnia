/// Access intent for typed playback only. Import/catalog legacy operations keep
/// their existing configuration. Requested bitrate never grants account access.
enum StreamPlaybackAccessPolicy: String, Sendable {
    /// Resolve without reading configured browser/file cookie settings.
    case publicAudio
    /// Use the explicitly authorized configured source; never downgrade to public.
    case configuredAccount
}
