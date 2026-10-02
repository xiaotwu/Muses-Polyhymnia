import Foundation

/// One normalized recovery explanation for Home and Account; never exposes raw errors.
@MainActor
enum WebHomeRecoveryCopy {
    static func message(for status: WebHomeSessionStatus) -> String {
        switch status {
        case .accountMismatch, .unavailable(.identityUnavailable):
            tr("Open YouTube Music in the approved browser, select the channel connected in Account settings, then check the session again. Public recommendations remain available.",
               "请在已批准的浏览器中打开 YouTube Music，选择账号设置中连接的频道，再检查会话。公共推荐仍可使用。")
        case .expired:
            tr("Sign in to YouTube Music in the approved browser, then check the session again in Account settings. Public recommendations remain available.",
               "请在已批准的浏览器中登录 YouTube Music，再到账号设置检查会话。公共推荐仍可使用。")
        case .unavailable(.cookieSourceUnavailable):
            tr("Check the approved browser session and its macOS access in Account settings, then retry the session. Public recommendations remain available.",
               "请在账号设置检查已批准的浏览器会话及其 macOS 访问权限，再重试会话。公共推荐仍可使用。")
        case .disabledByBuild:
            tr("This build does not support Personalized Home. Public recommendations remain available.",
               "此构建不支持个性化首页。公共推荐仍可使用。")
        case .pendingConsent:
            tr("Review the dedicated browser consent in Account settings to enable Personalized Home. Public recommendations remain available.",
               "请在账号设置查看独立的浏览器同意流程，以启用个性化首页。公共推荐仍可使用。")
        case .closed:
            tr("Set up or check Personalized Home in Account settings. Public recommendations remain available.",
               "请在账号设置配置或检查个性化首页。公共推荐仍可使用。")
        case .checking, .refreshing:
            tr("Checking the approved browser session. Public recommendations remain available while you wait.",
               "正在检查已批准的浏览器会话。等待期间仍可使用公共推荐。")
        case .shapeChanged:
            tr("Personalized Home could not read the current YouTube response. Retry later or inspect diagnostics; public recommendations remain available.",
               "个性化首页无法读取当前 YouTube 响应。可稍后重试或查看诊断；公共推荐仍可使用。")
        case .available, .unavailable:
            tr("Personalized Home could not refresh. Retry the approved session in Account settings or use public recommendations.",
               "个性化首页未能刷新。可在账号设置重试已批准的会话，或使用公共推荐。")
        }
    }
}
