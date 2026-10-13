import Foundation

/// One normalized recovery explanation for Home and Account; never exposes raw errors.
@MainActor
enum WebHomeRecoveryCopy {
    static func message(for status: WebHomeSessionStatus) -> String {
        switch status {
        case .accountMismatch, .unavailable(.identityUnavailable):
            tr("Open YouTube Music in the approved browser, select the channel connected in Account settings, then check the session again.",
               "请在已批准的浏览器中打开 YouTube Music，选择账号设置中连接的频道，再检查会话。",
               zhHant: "請在已核准的瀏覽器中開啟 YouTube Music，選擇帳號設定中連接的頻道，再檢查工作階段。")
        case .expired:
            tr("Sign in to YouTube Music in the approved browser, then check the session again in Account settings.",
               "请在已批准的浏览器中登录 YouTube Music，再到账号设置检查会话。",
               zhHant: "請在已核准的瀏覽器中登入 YouTube Music，再到帳號設定檢查工作階段。")
        case .unavailable(.cookieSourceUnavailable):
            tr("Check the approved browser session and its macOS access in Account settings, then retry the session.",
               "请在账号设置检查已批准的浏览器会话及其 macOS 访问权限，再重试会话。",
               zhHant: "請在帳號設定檢查已核准的瀏覽器工作階段及其 macOS 存取權限，再重試工作階段。")
        case .disabledByBuild:
            tr("This build does not support Personalized Home. Choose Muses recommendations to browse your library.",
               "此构建不支持个性化首页。可选择 Muses 推荐浏览你的资料库。",
               zhHant: "此版本不支援個人化首頁。可選擇 Muses 推薦瀏覽你的資料庫。")
        case .pendingConsent:
            tr("Review the dedicated browser consent in Account settings to enable Personalized Home.",
               "请在账号设置查看独立的浏览器同意流程，以启用个性化首页。",
               zhHant: "請在帳號設定查看獨立的瀏覽器同意流程，以啟用個人化首頁。")
        case .closed:
            tr("Set up or check Personalized Home in Account settings.",
               "请在账号设置配置或检查个性化首页。",
               zhHant: "請在帳號設定設定或檢查個人化首頁。")
        case .checking, .refreshing:
            tr("Checking the approved browser session for your connected account.",
               "正在检查已连接账号对应的浏览器会话。",
               zhHant: "正在檢查已連接帳號對應的瀏覽器工作階段。")
        case .shapeChanged:
            tr("Personalized Home could not read the current YouTube response. Retry later or inspect Diagnostics.",
               "个性化首页无法读取当前 YouTube 响应。可稍后重试或查看诊断。",
               zhHant: "個人化首頁無法讀取目前的 YouTube 回應。可稍後重試或查看診斷。")
        case .unavailable(.oauthRequired):
            tr("Connect your YouTube account before setting up Personalized Home.",
               "请先连接你的 YouTube 账号，再配置个性化首页。",
               zhHant: "請先連接你的 YouTube 帳號，再設定個人化首頁。")
        case .available:
            tr("The approved browser session matches your connected YouTube account.",
               "已批准的浏览器会话与你连接的 YouTube 账号匹配。",
               zhHant: "已核准的瀏覽器工作階段與你連接的 YouTube 帳號相符。")
        case .unavailable:
            tr("Personalized Home could not refresh. Retry the approved session in Account settings or choose Muses recommendations.",
               "个性化首页未能刷新。可在账号设置重试已批准的会话，或选择 Muses 推荐。",
               zhHant: "個人化首頁未能重新整理。可在帳號設定重試已核准的工作階段，或選擇 Muses 推薦。")
        }
    }
}
