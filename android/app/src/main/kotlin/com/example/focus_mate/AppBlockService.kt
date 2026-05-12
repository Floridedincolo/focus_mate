package com.example.focus_mate

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.WindowManager
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import android.widget.LinearLayout
import android.graphics.PixelFormat
import android.content.Intent
import android.util.Log
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.graphics.drawable.Drawable
import android.graphics.Color
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.widget.LinearLayout.LayoutParams
import android.widget.Button
import android.view.animation.AccelerateDecelerateInterpolator
import android.net.Uri
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AppBlockService : AccessibilityService() {

    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var overlayShown = false
    private var lastActionTime = 0L

    // Per-app cooldown used only by 'light' mode templates: after blocking app X,
    // we leave X alone for 30s so the user can briefly use it.
    private val lastBlockedPerApp = HashMap<String, Long>()

    // Cooldown for in-app feature blocks (key: "pkg/feature"). Prevents the
    // service from spamming GLOBAL_ACTION_BACK while a feature is on screen.
    private val lastInAppBlock = HashMap<String, Long>()

    // Lockdown-mode state.
    private var lockdownActive = false
    private var lockdownEndMs = 0L
    private var lockdownTaskName: String? = null
    private var lockdownCountdownView: TextView? = null
    private var lockdownTickRunnable: Runnable? = null
    // True while the user is on a phone call (we briefly hide the overlay
    // so the dialer is usable). Restored when the dialer is left.
    private var lockdownPausedForCall = false

    // Dialer packages we trust to be visible during lockdown. The OS default
    // dialer is added at runtime via TelecomManager.
    private val dialerExemptPackages = mutableSetOf(
        "com.android.dialer",
        "com.google.android.dialer",
        "com.samsung.android.dialer",
        "com.android.server.telecom",
        "com.android.incallui",
    )

    // Variabile pentru verificarea periodică (Heartbeat)
    private var lastPackageSeen: String? = null
    private val handler = Handler(Looper.getMainLooper())
    private var tickRunnable: Runnable? = null

    companion object {
        const val PREF_PREVENTED_PREFIX = "prevented_distractions_"
        val dayFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

        // Safety net: propriul app nu se blochează niciodată pe sine.
        private val ALWAYS_EXEMPT = setOf("com.example.focus_mate")

        // Browser package → URL bar view ID(s)
        private val BROWSER_URL_BAR_IDS = mapOf(
            "com.android.chrome" to listOf("com.android.chrome:id/url_bar", "com.android.chrome:id/omnibox_text"),
            "org.mozilla.firefox" to listOf("org.mozilla.firefox:id/mozac_browser_toolbar_url_view"),
            "org.mozilla.firefox_beta" to listOf("org.mozilla.firefox_beta:id/mozac_browser_toolbar_url_view"),
            "com.opera.browser" to listOf("com.opera.browser:id/url_field"),
            "com.opera.mini.native" to listOf("com.opera.mini.native:id/url_field"),
            "com.brave.browser" to listOf("com.brave.browser:id/url_bar"),
            "com.microsoft.emmx" to listOf("com.microsoft.emmx:id/url_bar"),
            "com.sec.android.app.sbrowser" to listOf("com.sec.android.app.sbrowser:id/location_bar_edit_text"),
            "com.UCMobile.intl" to listOf("com.UCMobile.intl:id/title_bar_input"),
            "com.vivaldi.browser" to listOf("com.vivaldi.browser:id/url_bar"),
        )

        // ── In-app feature detectors ──
        // For each (package, featureId) we list multi-pronged signals: view IDs
        // (most stable), content-descriptions (resilient to UI text changes),
        // and visible text fallbacks (with common localizations).
        // Detection is fuzzy on purpose: any single match flips the feature on,
        // but we also require the node to be visible to the user.
        // Each detector is intentionally narrow: signals that match the
        // *active* feature page only — not toolbar icons or tabs that are
        // visible on every screen. View IDs are the most reliable signal;
        // contentDesc/text are last-resort fallbacks and must be specific
        // enough that they don't appear on the app's home/feed.
        //
        // `viewIdsActive` view IDs only count if the node is currently
        // focused or selected — used for things like a search EditText so
        // it doesn't trigger when the user is merely on the home feed.
        // `selectedContentDescs` / `selectedTexts` only count when the
        // matching node is in `isSelected=true` state — used to detect that
        // a bottom-nav tab (Reels, Explore, ...) is currently the active
        // destination, rather than just being a label in the nav bar.
        data class InAppDetector(
            val viewIds: List<String> = emptyList(),
            val viewIdsActive: List<String> = emptyList(),
            val contentDescs: List<String> = emptyList(),
            val texts: List<String> = emptyList(),
            val selectedContentDescs: List<String> = emptyList(),
            val selectedTexts: List<String> = emptyList()
        )

        private val IN_APP_DETECTORS: Map<String, Map<String, InAppDetector>> = mapOf(
            "com.google.android.youtube" to mapOf(
                // The Shorts player has its own fullscreen container.
                "shorts" to InAppDetector(
                    viewIds = listOf(
                        "com.google.android.youtube:id/reel_recycler",
                        "com.google.android.youtube:id/reel_player_page_container",
                        "com.google.android.youtube:id/reel_watch_player",
                    )
                ),
                // Only fire when the search field is actively focused (i.e.
                // the user opened search) — NOT when the search icon is just
                // present in the toolbar of the home feed.
                "video_search" to InAppDetector(
                    viewIdsActive = listOf(
                        "com.google.android.youtube:id/search_edit_text"
                    )
                ),
                // Comments panel is a bottom sheet with this container id.
                "comments" to InAppDetector(
                    viewIds = listOf(
                        "com.google.android.youtube:id/watch_comments",
                        "com.google.android.youtube:id/comments_container",
                    )
                ),
                // Picture-in-picture has no on-screen node inside YouTube
                // itself; the system PiP overlay belongs to com.android.systemui.
                // This detector is effectively a no-op for now.
                "pip" to InAppDetector(),
            ),
            "com.instagram.android" to mapOf(
                // Story viewer has a "Reply to <user>" / "Send message"
                // input + an options button described by the author's name.
                // We rely on the "Reply to" / "Send message" contentDesc
                // which only appears on the fullscreen story viewer.
                "stories" to InAppDetector(
                    contentDescs = listOf(
                        "reply to ",
                        "send message",
                        "story by ",
                        "trimite mesaj",
                    )
                ),
                // Reels: fires when the Reels bottom-nav tab is currently
                // selected (user is on the Reels feed). Also catches the
                // fullscreen reels viewer via author byline contentDesc.
                "reels" to InAppDetector(
                    selectedContentDescs = listOf("reels"),
                    contentDescs = listOf("reels by ", "reels viewer")
                ),
                // Explore = the Search tab in IG's bottom nav. Tab is
                // selected only when user is on the explore grid.
                "explore" to InAppDetector(
                    selectedContentDescs = listOf("search and explore", "explore")
                ),
            ),
            "com.facebook.katana" to mapOf(
                // Facebook obfuscates view IDs heavily; we lean on highly
                // specific content descriptions for the fullscreen viewers.
                "reels" to InAppDetector(
                    contentDescs = listOf("reels viewer", "reels video")
                ),
                "stories" to InAppDetector(
                    contentDescs = listOf("story viewer")
                ),
            ),
            "com.snapchat.android" to mapOf(
                "spotlight" to InAppDetector(
                    contentDescs = listOf("spotlight viewer", "spotlight feed")
                ),
                "stories" to InAppDetector(
                    contentDescs = listOf("story viewer")
                ),
            ),
            "com.zhiliaoapp.musically" to mapOf(
                "fyp" to InAppDetector(
                    contentDescs = listOf("for you feed", "for you page")
                ),
                "search" to InAppDetector(
                    viewIdsActive = listOf(
                        "com.zhiliaoapp.musically:id/search_edit_text"
                    )
                ),
            ),
        )

        private val MOTIVATIONAL_SEARCHES = listOf(
            "productivity tips for students",
            "how to stay focused while studying",
            "motivational quotes for success",
            "benefits of deep work",
            "focus techniques pomodoro",
            "how to beat procrastination",
            "growth mindset tips",
            "best study habits",
            "importance of discipline",
            "how to build good habits",
        )
    }

    // Cache pentru a nu interoga PackageManager la fiecare tick.
    private var cachedHomePackages: Set<String> = emptySet()
    private var cachedHomePackagesAt: Long = 0L
    private val exemptDecisionCache = HashMap<String, Boolean>()

    private fun getHomePackages(): Set<String> {
        val now = System.currentTimeMillis()
        // Reîmprospătăm la fiecare 30s în caz că userul schimbă launcherul.
        if (now - cachedHomePackagesAt < 30_000L && cachedHomePackages.isNotEmpty()) {
            return cachedHomePackages
        }
        val result = mutableSetOf<String>()
        try {
            val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            val resolvers = packageManager.queryIntentActivities(homeIntent, 0)
            for (ri in resolvers) {
                ri.activityInfo?.packageName?.let { result.add(it) }
            }
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "❌ Eroare la enumerarea launcherelor: ${e.message}")
        }
        cachedHomePackages = result
        cachedHomePackagesAt = now
        return result
    }

    private fun getCurrentImePackage(): String? {
        return try {
            val imeId = Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
            // imeId are forma "package/.ServiceName"
            imeId?.substringBefore('/')?.takeIf { it.isNotBlank() }
        } catch (e: Exception) {
            null
        }
    }

    private fun isSystemExempt(packageName: String): Boolean {
        if (packageName in ALWAYS_EXEMPT) return true

        exemptDecisionCache[packageName]?.let { return it }

        // 1) Launcherul implicit / orice home app instalat.
        if (packageName in getHomePackages()) {
            exemptDecisionCache[packageName] = true
            return true
        }

        // 2) Tastatura activă.
        if (packageName == getCurrentImePackage()) {
            exemptDecisionCache[packageName] = true
            return true
        }

        // 3) Pachete fără icon de lansare = componente de sistem invizibile userului
        //    (Android System, SystemUI, servicii Google Play, overlay-uri OEM etc.).
        val hasLauncherIcon = try {
            packageManager.getLaunchIntentForPackage(packageName) != null
        } catch (e: Exception) {
            false
        }
        if (!hasLauncherIcon) {
            exemptDecisionCache[packageName] = true
            return true
        }

        // Note: nu mai exceptăm automat system apps non-updated. Pe emulator
        // și pe telefoane unde Play Store nu a actualizat încă Google apps
        // (Calendar, Maps etc.) acea regulă le scotea silent din blocare.
        // Verificarea launcher icon de mai sus filtrează deja componentele
        // OS invizibile (System UI, GMS internals, overlay-uri OEM).

        exemptDecisionCache[packageName] = false
        return false
    }

    private var lastWebBlockTime = 0L
    private var lastRedirectTime = 0L

    private fun isBrowser(packageName: String): Boolean = BROWSER_URL_BAR_IDS.containsKey(packageName)

    private fun extractUrlFromBrowser(packageName: String): String? {
        val root = rootInActiveWindow ?: return null
        try {
            val viewIds = BROWSER_URL_BAR_IDS[packageName] ?: return null
            for (viewId in viewIds) {
                val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
                if (!nodes.isNullOrEmpty()) {
                    val text = nodes[0].text?.toString()
                    if (!text.isNullOrBlank()) return text
                }
            }
            // Fallback: traverse all nodes looking for URL-like content in EditText
            return findUrlInNodeTree(root)
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "❌ Eroare la extragerea URL: ${e.message}")
            return null
        } finally {
            root.recycle()
        }
    }

    private fun findUrlInNodeTree(node: AccessibilityNodeInfo): String? {
        val text = node.text?.toString()
        if (text != null && node.className?.toString() == "android.widget.EditText") {
            if (text.contains(".") && !text.contains(" ")) return text
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findUrlInNodeTree(child)
            child.recycle()
            if (result != null) return result
        }
        return null
    }

    /**
     * Extracts just the host (domain) portion from a URL string.
     * Handles both full URLs (https://example.com/path?q=x) and
     * bare domains (example.com) as shown in browser URL bars.
     */
    private fun extractHost(url: String): String {
        val withoutProtocol = url.replace(Regex("^https?://"), "")
        return withoutProtocol.substringBefore("/").substringBefore("?").substringBefore("#")
    }

    private fun urlMatchesBlockedSite(url: String, blockedWebsites: List<String>, blockedKeywords: List<String>): Boolean {
        val urlLower = url.lowercase()

        for (site in blockedWebsites) {
            if (urlLower.contains(site.lowercase())) return true
        }
        for (keyword in blockedKeywords) {
            if (urlLower.contains(keyword.lowercase())) return true
        }
        return false
    }

    private fun redirectToMotivationalSearch() {
        val query = MOTIVATIONAL_SEARCHES.random()
        val searchUrl = "https://www.google.com/search?q=${Uri.encode(query)}"
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(searchUrl)).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        try {
            lastRedirectTime = System.currentTimeMillis()
            startActivity(intent)
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "❌ Eroare la redirect: ${e.message}")
            sendUserToHome()
        }
    }

    private var scheduledBlocks: JSONArray = JSONArray()
    private var currentTaskName: String? = null
    private var currentTaskStartTimeMs: Long = 0L
    private var currentTaskEndTimeMs: Long = 0L
    private var lastFileModified = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("AppAccessibilityService", "🔌 Serviciu conectat – Monitorizare activă!")
        refreshDefaultDialer()
        checkAndLoadSchedule()
        maintainLockdown()
        startPeriodicCheck()
    }

    // Pornește un timer care verifică aplicația curentă la fiecare 3 secunde
    private fun startPeriodicCheck() {
        tickRunnable = object : Runnable {
            override fun run() {
                checkAndLoadSchedule()
                maintainLockdown(lastPackageSeen)
                lastPackageSeen?.let { pkg ->
                    checkBlockingLogic(pkg)
                }
                handler.postDelayed(this, 3000)
            }
        }
        handler.post(tickRunnable!!)
    }

    private fun checkAndLoadSchedule() {
        try {
            val file = File(filesDir, "schedule.json")
            if (file.exists()) {
                val currentModified = file.lastModified()
                if (currentModified > lastFileModified) {
                    val jsonString = file.readText()
                    scheduledBlocks = JSONArray(jsonString)
                    lastFileModified = currentModified
                    Log.d("AppAccessibilityService", "📄 Orar sincronizat! (${scheduledBlocks.length()} ferestre)")
                }
            }
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "❌ Eroare la citirea orarului: ${e.message}")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        try {
            if (event == null) return

            val packageName = event.packageName?.toString() ?: return

            when (event.eventType) {
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                    lastPackageSeen = packageName
                    // Lockdown takes priority — if a lockdown window is
                    // active and the user just left the dialer, snap the
                    // overlay back BEFORE running the regular block logic.
                    maintainLockdown(packageName)
                    if (lockdownActive) return
                    checkBlockingLogic(packageName)
                }
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                    // Process content changes in browsers (URL navigation) and
                    // in apps with in-app feature detectors (Shorts, Reels, ...)
                    if (isBrowser(packageName) || IN_APP_DETECTORS.containsKey(packageName)) {
                        lastPackageSeen = packageName
                        checkBlockingLogic(packageName)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "❌ Eroare în onAccessibilityEvent: ${e.message}")
        }
    }

    private fun checkBlockingLogic(packageName: String) {
        if (isSystemExempt(packageName)) return

        checkAndLoadSchedule()

        val now = System.currentTimeMillis()
        var shouldBlockApp = false
        var shouldBlockWeb = false
        var foundTaskName: String? = null
        var foundStartMs = 0L
        var foundEndMs = 0L
        var foundMode = "hard"
        // Aggregated in-app feature flags active for this package across any
        // currently-active schedule window (union — most aggressive wins).
        val activeInAppFeatures = mutableSetOf<String>()

        for (i in 0 until scheduledBlocks.length()) {
            val block = scheduledBlocks.getJSONObject(i)
            val startMs = block.getLong("startMs")
            val endMs = block.getLong("endMs")

            if (now in startMs until endMs) {
                // Collect in-app feature flags for this package, if any.
                val inAppObj = block.optJSONObject("inAppBlocks")
                if (inAppObj != null) {
                    val arr = inAppObj.optJSONArray(packageName)
                    if (arr != null) {
                        for (k in 0 until arr.length()) {
                            activeInAppFeatures.add(arr.getString(k))
                        }
                    }
                }

                // Check app blocking
                val isWhitelist = block.getBoolean("isWhitelist")
                val appsArray = block.getJSONArray("apps")
                val blockedApps = mutableSetOf<String>()
                for (j in 0 until appsArray.length()) { blockedApps.add(appsArray.getString(j)) }

                val isAppBlocked = if (isWhitelist) !blockedApps.contains(packageName) else blockedApps.contains(packageName)

                if (isAppBlocked) {
                    shouldBlockApp = true
                    foundTaskName = block.getString("taskName")
                    foundStartMs = startMs
                    foundEndMs = endMs
                    foundMode = block.optString("mode", "hard")
                    break
                }

                // Check website/keyword blocking (only if current app is a browser)
                // Skip if we just redirected to a motivational search (avoid loop)
                if (isBrowser(packageName) && (now - lastRedirectTime > 10_000L)) {
                    val websitesArray = block.optJSONArray("blockedWebsites")
                    val keywordsArray = block.optJSONArray("blockedKeywords")
                    val blockedWebsites = mutableListOf<String>()
                    val blockedKeywords = mutableListOf<String>()
                    if (websitesArray != null) {
                        for (j in 0 until websitesArray.length()) blockedWebsites.add(websitesArray.getString(j))
                    }
                    if (keywordsArray != null) {
                        for (j in 0 until keywordsArray.length()) blockedKeywords.add(keywordsArray.getString(j))
                    }

                    if (blockedWebsites.isNotEmpty() || blockedKeywords.isNotEmpty()) {
                        val url = extractUrlFromBrowser(packageName)
                        if (url != null && urlMatchesBlockedSite(url, blockedWebsites, blockedKeywords)) {
                            shouldBlockWeb = true
                            foundTaskName = block.getString("taskName")
                            foundStartMs = startMs
                            foundEndMs = endMs
                            break
                        }
                    }
                }
            }
        }

        if (shouldBlockApp) {
            currentTaskName = foundTaskName
            currentTaskStartTimeMs = foundStartMs
            currentTaskEndTimeMs = foundEndMs

            // Light mode: per-app 30s cooldown so the user gets a warning,
            // then is left alone briefly. Hard mode: global 5s cooldown.
            if (foundMode == "light") {
                val lastSeen = lastBlockedPerApp[packageName] ?: 0L
                if (now - lastSeen < 30_000L) return
                lastBlockedPerApp[packageName] = now
            } else {
                if (now - lastActionTime < 5000) return
                lastActionTime = now
            }

            Log.d("AppAccessibilityService", "🚫 Blocare app ($foundMode) executată pentru $packageName la ora ${Date(now)}")

            val preventedCount = incrementPreventedDistractions()
            showOverlay(packageName, preventedCount)
            // Hard mode kicks user out so they can't bypass the overlay on
            // fullscreen apps. Light mode just shows the overlay and lets the
            // user dismiss it (with a 30s grace period before re-blocking).
            if (foundMode != "light") {
                Handler(Looper.getMainLooper()).postDelayed({ sendUserToHome() }, 100)
            } else {
                Handler(Looper.getMainLooper()).postDelayed({ removeOverlay() }, 4000)
            }
        } else if (shouldBlockWeb) {
            currentTaskName = foundTaskName
            currentTaskStartTimeMs = foundStartMs
            currentTaskEndTimeMs = foundEndMs

            if (now - lastWebBlockTime < 5000) return
            lastWebBlockTime = now

            Log.d("AppAccessibilityService", "🚫 Blocare website executată în $packageName la ora ${Date(now)}")

            val preventedCount = incrementPreventedDistractions()
            val url = extractUrlFromBrowser(packageName)
            val siteName = if (url != null) extractHost(url) else "Website"
            showWebOverlay(siteName, preventedCount)
        } else if (activeInAppFeatures.isNotEmpty()) {
            handleInAppFeatureBlock(packageName, activeInAppFeatures)
        }
    }

    /**
     * Walks the active window's accessibility tree looking for nodes that
     * match any enabled in-app feature detector for [packageName]. If found,
     * dismisses the feature with GLOBAL_ACTION_BACK (works for fullscreen
     * Shorts/Reels viewers and most modal feature panels).
     *
     * Per (package, feature) cooldown of 4 seconds avoids spamming back-presses
     * while the same feature is on screen.
     */
    private fun handleInAppFeatureBlock(packageName: String, enabled: Set<String>) {
        val detectors = IN_APP_DETECTORS[packageName] ?: return
        val root = rootInActiveWindow ?: return
        val now = System.currentTimeMillis()
        try {
            for (featureId in enabled) {
                val det = detectors[featureId] ?: continue
                // Per (pkg, feature) cooldown: long enough that we don't spam
                // the overlay while the feature stays on screen, short enough
                // to fire again on a fresh attempt.
                val cooldownKey = "$packageName/$featureId"
                if (now - (lastInAppBlock[cooldownKey] ?: 0L) < 20_000L) continue
                if (detectFeature(root, det)) {
                    lastInAppBlock[cooldownKey] = now
                    Log.d("AppAccessibilityService", "🚫 In-app block: $packageName / $featureId")

                    // Find the active schedule window's task name so the
                    // overlay can show the same "You need to focus on: X"
                    // line as the regular block.
                    populateActiveTaskContext(packageName)
                    val preventedCount = incrementPreventedDistractions()
                    showInAppOverlay(packageName, featureId, preventedCount)
                    // Pop back to dismiss the feature view. Slight delay so
                    // the overlay actually paints before the underlying app
                    // reacts to the back press.
                    Handler(Looper.getMainLooper()).postDelayed({
                        performGlobalAction(GLOBAL_ACTION_BACK)
                    }, 250)
                    return
                }
            }
        } finally {
            root.recycle()
        }
    }

    /**
     * Looks up the currently-active schedule window (if any) for [packageName]
     * and stores its task name / time range on the instance so overlay UI can
     * render the standard "focus on X" hint.
     */
    private fun populateActiveTaskContext(packageName: String) {
        val now = System.currentTimeMillis()
        for (i in 0 until scheduledBlocks.length()) {
            val block = scheduledBlocks.getJSONObject(i)
            val startMs = block.getLong("startMs")
            val endMs = block.getLong("endMs")
            if (now in startMs until endMs) {
                currentTaskName = block.optString("taskName", null)
                currentTaskStartTimeMs = startMs
                currentTaskEndTimeMs = endMs
                return
            }
        }
    }

    private fun detectFeature(root: AccessibilityNodeInfo, det: InAppDetector): Boolean {
        // 1) Plain view-id lookup — node must be visible.
        for (vid in det.viewIds) {
            val nodes = try { root.findAccessibilityNodeInfosByViewId(vid) } catch (e: Exception) { null }
            if (!nodes.isNullOrEmpty()) {
                var hit = false
                for (n in nodes) {
                    if (!hit && n.isVisibleToUser) hit = true
                    n.recycle()
                }
                if (hit) return true
            }
        }
        // 2) Active view-id lookup — node must be visible AND (focused OR
        // selected). Used for things like a search EditText that we only
        // want to count when the user has actually engaged with it.
        for (vid in det.viewIdsActive) {
            val nodes = try { root.findAccessibilityNodeInfosByViewId(vid) } catch (e: Exception) { null }
            if (!nodes.isNullOrEmpty()) {
                var hit = false
                for (n in nodes) {
                    if (!hit && n.isVisibleToUser && (n.isFocused || n.isSelected)) hit = true
                    n.recycle()
                }
                if (hit) return true
            }
        }
        val hasTextSignals = det.contentDescs.isNotEmpty() ||
            det.texts.isNotEmpty() ||
            det.selectedContentDescs.isNotEmpty() ||
            det.selectedTexts.isNotEmpty()
        if (!hasTextSignals) return false
        // 3) Bounded BFS that handles both plain and "selected-only" text /
        // contentDescription matches in a single tree walk.
        return bfsMatch(
            root,
            det.contentDescs,
            det.texts,
            det.selectedContentDescs,
            det.selectedTexts,
            maxNodes = 400
        )
    }

    private fun bfsMatch(
        root: AccessibilityNodeInfo,
        contentDescs: List<String>,
        texts: List<String>,
        selectedContentDescs: List<String>,
        selectedTexts: List<String>,
        maxNodes: Int
    ): Boolean {
        val queue: ArrayDeque<AccessibilityNodeInfo> = ArrayDeque()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < maxNodes) {
            val node = queue.removeFirst()
            visited++
            try {
                if (node.isVisibleToUser) {
                    val cd = node.contentDescription?.toString()?.lowercase()
                    if (cd != null) {
                        for (needle in contentDescs) {
                            if (cd.contains(needle.lowercase())) return true
                        }
                        if (node.isSelected) {
                            for (needle in selectedContentDescs) {
                                if (cd.contains(needle.lowercase())) return true
                            }
                        }
                    }
                    val tx = node.text?.toString()?.lowercase()
                    if (tx != null) {
                        for (needle in texts) {
                            if (tx.contains(needle.lowercase())) return true
                        }
                        if (node.isSelected) {
                            for (needle in selectedTexts) {
                                if (tx.contains(needle.lowercase())) return true
                            }
                        }
                    }
                }
                for (i in 0 until node.childCount) {
                    val c = node.getChild(i) ?: continue
                    queue.add(c)
                }
            } catch (e: Exception) {
                // Ignore individual node errors and keep walking.
            } finally {
                if (node !== root) node.recycle()
            }
        }
        // Drain any remaining nodes so we don't leak them.
        while (queue.isNotEmpty()) {
            val n = queue.removeFirst()
            if (n !== root) n.recycle()
        }
        return false
    }

    // AICI E MAGIA NOUĂ: Salvăm atât totalul pe zi, cât și totalul pe ora exactă!
    private fun incrementPreventedDistractions(): Int {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val now = Date()

            // 1. Găleata mare (Totalul pe Zi)
            val todayStr = dayFormat.format(now)
            val todayKey = "flutter." + PREF_PREVENTED_PREFIX + todayStr
            val currentTotal = prefs.getInt(todayKey, 0)
            val newTotal = currentTotal + 1
            prefs.edit().putInt(todayKey, newTotal).apply()

            // 2. Găleata mică (Totalul pe Ora curentă)
            val hourStr = SimpleDateFormat("HH", Locale.US).format(now) // returnează "00", "01" ... "23"
            val hourKey = todayKey + "_" + hourStr
            val currentHourly = prefs.getInt(hourKey, 0)
            prefs.edit().putInt(hourKey, currentHourly + 1).apply()

            return newTotal // Pentru a-l afișa pe ecranul de overlay
        } catch (e: Exception) {
            return 1
        }
    }

    private fun sendUserToHome() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun loadAppIconAndLabel(pkg: String): Pair<Drawable?, String?> {
        try { return Pair(packageManager.getApplicationIcon(pkg), packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0))?.toString()) } catch (e: Exception) {}
        return Pair(null, null)
    }

    private fun showOverlay(packageName: String, preventedCount: Int) {
        if (overlayShown) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) return

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val scale = resources.displayMetrics.density
        val (iconDrawable, appLabel) = loadAppIconAndLabel(packageName)

        val backdrop = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#AA000000"))
            isClickable = true
            isFocusable = true
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = GradientDrawable().apply {
                cornerRadius = 36f * scale
                setColor(Color.parseColor("#22FFFFFF"))
                setStroke((1 * scale).toInt(), Color.parseColor("#33FFFFFF"))
            }
            setPadding((32 * scale).toInt(), (48 * scale).toInt(), (32 * scale).toInt(), (40 * scale).toInt())
            layoutParams = FrameLayout.LayoutParams((320 * scale).toInt(), FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER)
        }

        iconDrawable?.let {
            card.addView(ImageView(this).apply {
                setImageDrawable(it)
                layoutParams = LinearLayout.LayoutParams((72 * scale).toInt(), (72 * scale).toInt()).apply { bottomMargin = (24 * scale).toInt() }
            })
        }

        card.addView(TextView(this).apply {
            text = "${appLabel ?: "App"} is blocked right now"
            textSize = 22f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = (12 * scale).toInt() }
        })

        if (!currentTaskName.isNullOrBlank()) {
            card.addView(TextView(this).apply {
                text = "You need to focus on:"
                textSize = 14f; setTextColor(Color.parseColor("#AAFFFFFF")); gravity = Gravity.CENTER
            })
            card.addView(TextView(this).apply {
                text = currentTaskName
                textSize = 18f; setTextColor(Color.WHITE); gravity = Gravity.CENTER
                typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
                layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { topMargin = (4 * scale).toInt(); bottomMargin = (4 * scale).toInt() }
            })

            val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
            val startTimeStr = timeFormat.format(Date(currentTaskStartTimeMs))
            val endTimeStr = timeFormat.format(Date(currentTaskEndTimeMs))

            card.addView(TextView(this).apply {
                text = "$startTimeStr - $endTimeStr"
                textSize = 14f; setTextColor(Color.parseColor("#FFA726")); gravity = Gravity.CENTER
                typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
                layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = (24 * scale).toInt() }
            })
        }

        card.addView(TextView(this).apply {
            text = "Distractions prevented today: $preventedCount"
            textSize = 12f
            setTextColor(Color.parseColor("#88FFFFFF"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = (24 * scale).toInt()
            }
        })

        card.addView(Button(this).apply {
            text = "OK"
            setTextColor(Color.BLACK)
            isAllCaps = false
            textSize = 16f
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            background = GradientDrawable().apply {
                cornerRadius = 24f * scale
                setColor(Color.WHITE)
            }
            layoutParams = LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, (58 * scale).toInt()).apply {
                bottomMargin = (16 * scale).toInt()
            }
            setOnClickListener { removeOverlay() }
        })

        backdrop.addView(card)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM,
            PixelFormat.TRANSLUCENT
        )

        try {
            windowManager?.addView(backdrop, params)
            overlayView = backdrop; overlayShown = true
            card.alpha = 0f; card.scaleX = 0.85f; card.scaleY = 0.85f
            card.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(450).setInterpolator(AccelerateDecelerateInterpolator()).start()
        } catch (e: Exception) { overlayShown = false }
    }

    private fun removeOverlay() {
        if (!overlayShown) return
        try { windowManager?.removeViewImmediate(overlayView) } catch (e: Exception) {}
        overlayView = null; overlayShown = false
    }

    private fun showWebOverlay(siteName: String, preventedCount: Int) {
        if (overlayShown) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            redirectToMotivationalSearch()
            return
        }

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val scale = resources.displayMetrics.density

        val backdrop = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#AA000000"))
            isClickable = true
            isFocusable = true
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = GradientDrawable().apply {
                cornerRadius = 36f * scale
                setColor(Color.parseColor("#22FFFFFF"))
                setStroke((1 * scale).toInt(), Color.parseColor("#33FFFFFF"))
            }
            setPadding((32 * scale).toInt(), (48 * scale).toInt(), (32 * scale).toInt(), (40 * scale).toInt())
            layoutParams = FrameLayout.LayoutParams((320 * scale).toInt(), FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER)
        }

        // Globe icon placeholder
        card.addView(TextView(this).apply {
            text = "\uD83C\uDF10" // 🌐
            textSize = 48f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = (16 * scale).toInt() }
        })

        card.addView(TextView(this).apply {
            text = "$siteName is blocked"
            textSize = 22f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = (12 * scale).toInt() }
        })

        if (!currentTaskName.isNullOrBlank()) {
            card.addView(TextView(this).apply {
                text = "You need to focus on:"
                textSize = 14f; setTextColor(Color.parseColor("#AAFFFFFF")); gravity = Gravity.CENTER
            })
            card.addView(TextView(this).apply {
                text = currentTaskName
                textSize = 18f; setTextColor(Color.WHITE); gravity = Gravity.CENTER
                typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
                layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { topMargin = (4 * scale).toInt(); bottomMargin = (4 * scale).toInt() }
            })

            val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
            val startTimeStr = timeFormat.format(Date(currentTaskStartTimeMs))
            val endTimeStr = timeFormat.format(Date(currentTaskEndTimeMs))

            card.addView(TextView(this).apply {
                text = "$startTimeStr - $endTimeStr"
                textSize = 14f; setTextColor(Color.parseColor("#FFA726")); gravity = Gravity.CENTER
                typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
                layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = (24 * scale).toInt() }
            })
        }

        card.addView(TextView(this).apply {
            text = "Distractions prevented today: $preventedCount"
            textSize = 12f
            setTextColor(Color.parseColor("#88FFFFFF"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = (24 * scale).toInt()
            }
        })

        card.addView(Button(this).apply {
            text = "OK"
            setTextColor(Color.BLACK)
            isAllCaps = false
            textSize = 16f
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            background = GradientDrawable().apply {
                cornerRadius = 24f * scale
                setColor(Color.WHITE)
            }
            layoutParams = LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, (58 * scale).toInt()).apply {
                bottomMargin = (16 * scale).toInt()
            }
            setOnClickListener {
                removeOverlay()
                redirectToMotivationalSearch()
            }
        })

        backdrop.addView(card)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM,
            PixelFormat.TRANSLUCENT
        )

        try {
            windowManager?.addView(backdrop, params)
            overlayView = backdrop; overlayShown = true
            card.alpha = 0f; card.scaleX = 0.85f; card.scaleY = 0.85f
            card.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(450).setInterpolator(AccelerateDecelerateInterpolator()).start()
        } catch (e: Exception) { overlayShown = false }
    }

    /**
     * The source of truth for lockdown lifecycle. Walks the schedule, finds a
     * currently-active window with `mode == "lockdown"`, and toggles the
     * overlay on/off based purely on time — independent of which app the
     * user has opened.
     *
     * Safe to call on every tick / event; idempotent.
     */
    private fun maintainLockdown(currentPackage: String? = null) {
        val now = System.currentTimeMillis()
        var taskName: String? = null
        var endMs = 0L
        for (i in 0 until scheduledBlocks.length()) {
            val block = scheduledBlocks.getJSONObject(i)
            if (block.optString("mode") != "lockdown") continue
            val s = block.getLong("startMs")
            val e = block.getLong("endMs")
            if (now in s until e) {
                taskName = block.optString("taskName").takeIf { it.isNotBlank() }
                endMs = e
                break
            }
        }

        if (endMs > 0) {
            // Window is active.
            if (lockdownPausedForCall) {
                // User opened the dialer. Keep overlay hidden while the
                // current foreground is the dialer; restore the moment they
                // leave it.
                val pkg = currentPackage
                if (pkg != null && pkg !in dialerExemptPackages) {
                    Log.d("AppAccessibilityService", "🛡️ Left dialer ($pkg) — restoring lockdown")
                    lockdownPausedForCall = false
                    showLockdownOverlay(taskName, endMs)
                }
                return
            }
            if (!lockdownActive) {
                Log.d("AppAccessibilityService", "🛡️ Lockdown window entered until ${Date(endMs)}")
                incrementPreventedDistractions()
                showLockdownOverlay(taskName, endMs)
            } else {
                // Already active — just refresh task name/end in case the
                // schedule changed underfoot.
                lockdownTaskName = taskName
                lockdownEndMs = endMs
            }
        } else {
            // No active lockdown window.
            if (lockdownActive || lockdownPausedForCall) {
                Log.d("AppAccessibilityService", "🛡️ Lockdown window ended")
                dismissLockdown()
            }
        }
    }

    /** Records the OS default dialer so it's allowed through during lockdown. */
    private fun refreshDefaultDialer() {
        try {
            val tm = getSystemService(Context.TELECOM_SERVICE) as? android.telecom.TelecomManager
            tm?.defaultDialerPackage?.let { dialerExemptPackages.add(it) }
        } catch (_: Exception) {}
    }

    /**
     * Persistent fullscreen lockdown screen — covers everything (including the
     * launcher) with the current task name and a live countdown to the end of
     * the focus window. The only escape hatch is the phone-call icon, which
     * temporarily hides the overlay while the dialer is foregrounded.
     */
    private fun showLockdownOverlay(taskName: String?, endMs: Long) {
        if (lockdownActive) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) return

        // Remove any pre-existing non-lockdown overlay first (we want full
        // control of the screen — no leftover "OK" buttons floating around).
        removeOverlay()

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val scale = resources.displayMetrics.density
        val lockdownGreen = Color.parseColor("#3CA374")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(lockdownGreen)
            isClickable = true; isFocusable = true
        }

        val untilFormat = SimpleDateFormat("EEE HH:mm:ss", Locale.getDefault())
        root.addView(TextView(this).apply {
            text = "Until ${untilFormat.format(Date(endMs))}"
            textSize = 16f
            setTextColor(Color.parseColor("#CCFFFFFF"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = (8 * scale).toInt() }
        })

        val countdown = TextView(this).apply {
            text = formatCountdown(endMs - System.currentTimeMillis())
            textSize = 56f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.create("sans-serif-light", android.graphics.Typeface.NORMAL)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = (16 * scale).toInt() }
        }
        root.addView(countdown)
        lockdownCountdownView = countdown

        if (!taskName.isNullOrBlank()) {
            root.addView(TextView(this).apply {
                text = taskName
                textSize = 22f
                setTextColor(Color.WHITE)
                typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
                gravity = Gravity.CENTER
                setPadding((24 * scale).toInt(), 0, (24 * scale).toInt(), 0)
                layoutParams = LinearLayout.LayoutParams(
                    LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = (8 * scale).toInt() }
            })
        }

        root.addView(TextView(this).apply {
            text = "Focus mode is locked until the session ends."
            textSize = 13f
            setTextColor(Color.parseColor("#AAFFFFFF"))
            gravity = Gravity.CENTER
            setPadding((32 * scale).toInt(), 0, (32 * scale).toInt(), 0)
            layoutParams = LinearLayout.LayoutParams(
                LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = (48 * scale).toInt() }
        })

        // Phone-call escape hatch. The only way out of lockdown until the
        // session ends. Tapping opens the system dialer; the overlay
        // auto-pauses while the dialer is foregrounded and snaps back the
        // moment the user leaves it.
        val callButton = buildLockdownCallButton(scale)
        root.addView(callButton)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            // Touchable overlay so taps don't fall through to the underlying
            // app. No FLAG_NOT_FOCUSABLE so back-press is consumed.
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
            PixelFormat.OPAQUE
        )

        try {
            windowManager?.addView(root, params)
            overlayView = root
            overlayShown = true
            lockdownActive = true
            lockdownEndMs = endMs
            lockdownTaskName = taskName
            startLockdownTick()
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "❌ Lockdown overlay failed: ${e.message}")
            lockdownActive = false
        }
    }

    private fun startLockdownTick() {
        stopLockdownTick()
        val r = object : Runnable {
            override fun run() {
                val remaining = lockdownEndMs - System.currentTimeMillis()
                if (remaining <= 0) {
                    Log.d("AppAccessibilityService", "🛡️ Lockdown window ended — dismissing overlay")
                    dismissLockdown()
                    return
                }
                lockdownCountdownView?.text = formatCountdown(remaining)
                handler.postDelayed(this, 1000)
            }
        }
        lockdownTickRunnable = r
        handler.post(r)
    }

    private fun stopLockdownTick() {
        lockdownTickRunnable?.let { handler.removeCallbacks(it) }
        lockdownTickRunnable = null
    }

    private fun dismissLockdown() {
        stopLockdownTick()
        lockdownActive = false
        lockdownPausedForCall = false
        lockdownEndMs = 0L
        lockdownTaskName = null
        lockdownCountdownView = null
        removeOverlay()
    }

    /**
     * Builds the circular phone-call button shown on the lockdown overlay.
     * White outline + handset glyph, matching the design.
     */
    private fun buildLockdownCallButton(scale: Float): View {
        val size = (84 * scale).toInt()
        return TextView(this).apply {
            // The classic phone handset glyph. Unicode is rendered as a
            // monochrome symbol on every Android skin, which fits the
            // green minimalist look.
            text = "☎"
            textSize = 34f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setStroke((2 * scale).toInt(), Color.WHITE)
                setColor(Color.TRANSPARENT)
            }
            layoutParams = LinearLayout.LayoutParams(size, size)
            isClickable = true; isFocusable = true
            setOnClickListener { launchDialerFromLockdown() }
        }
    }

    private fun launchDialerFromLockdown() {
        if (!lockdownActive) return
        try {
            refreshDefaultDialer()
            // ACTION_DIAL opens the dialer without requiring CALL_PHONE perm.
            val intent = Intent(Intent.ACTION_DIAL).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            // Pause lockdown BEFORE launching, otherwise our own overlay
            // will sit on top of the dialer. We clear `lockdownActive` too
            // so the re-show path (when the user leaves the dialer) isn't
            // blocked by the idempotency guard in showLockdownOverlay.
            lockdownPausedForCall = true
            lockdownActive = false
            stopLockdownTick()
            removeOverlay()
            startActivity(intent)
            Log.d("AppAccessibilityService", "🛡️ Lockdown paused for dialer")
        } catch (e: Exception) {
            Log.e("AppAccessibilityService", "❌ Could not launch dialer: ${e.message}")
            // If we failed to launch the dialer, undo the pause so we don't
            // leave the user stuck without an overlay AND without a dialer.
            lockdownPausedForCall = false
            maintainLockdown()
        }
    }

    private fun formatCountdown(remainingMs: Long): String {
        if (remainingMs <= 0) return "00:00:00"
        val totalSec = remainingMs / 1000
        val h = totalSec / 3600
        val m = (totalSec % 3600) / 60
        val s = totalSec % 60
        return String.format(Locale.US, "%02d:%02d:%02d", h, m, s)
    }

    private fun featureLabel(featureId: String): String = when (featureId) {
        "shorts" -> "Shorts"
        "reels" -> "Reels"
        "stories" -> "Stories"
        "explore" -> "Explore"
        "spotlight" -> "Spotlight"
        "fyp" -> "For You feed"
        "comments" -> "Comments"
        "video_search", "search" -> "Search"
        "pip" -> "Picture-in-picture"
        else -> featureId.replaceFirstChar { it.uppercase() }
    }

    private fun showInAppOverlay(packageName: String, featureId: String, preventedCount: Int) {
        if (overlayShown) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) return

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val scale = resources.displayMetrics.density
        val (iconDrawable, appLabel) = loadAppIconAndLabel(packageName)
        val featureName = featureLabel(featureId)

        val backdrop = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#AA000000"))
            isClickable = true; isFocusable = true
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = GradientDrawable().apply {
                cornerRadius = 36f * scale
                setColor(Color.parseColor("#22FFFFFF"))
                setStroke((1 * scale).toInt(), Color.parseColor("#33FFFFFF"))
            }
            setPadding((32 * scale).toInt(), (48 * scale).toInt(), (32 * scale).toInt(), (40 * scale).toInt())
            layoutParams = FrameLayout.LayoutParams((320 * scale).toInt(), FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER)
        }

        iconDrawable?.let {
            card.addView(ImageView(this).apply {
                setImageDrawable(it)
                layoutParams = LinearLayout.LayoutParams((72 * scale).toInt(), (72 * scale).toInt()).apply { bottomMargin = (24 * scale).toInt() }
            })
        }

        card.addView(TextView(this).apply {
            text = "$featureName is blocked"
            textSize = 22f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = (6 * scale).toInt() }
        })

        card.addView(TextView(this).apply {
            text = "You can still use ${appLabel ?: "this app"} — just not this part."
            textSize = 13f
            setTextColor(Color.parseColor("#AAFFFFFF"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = (16 * scale).toInt() }
        })

        if (!currentTaskName.isNullOrBlank()) {
            card.addView(TextView(this).apply {
                text = "You need to focus on:"
                textSize = 14f; setTextColor(Color.parseColor("#AAFFFFFF")); gravity = Gravity.CENTER
            })
            card.addView(TextView(this).apply {
                text = currentTaskName
                textSize = 18f; setTextColor(Color.WHITE); gravity = Gravity.CENTER
                typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
                layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { topMargin = (4 * scale).toInt(); bottomMargin = (16 * scale).toInt() }
            })
        }

        card.addView(TextView(this).apply {
            text = "Distractions prevented today: $preventedCount"
            textSize = 12f
            setTextColor(Color.parseColor("#88FFFFFF"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = (24 * scale).toInt() }
        })

        card.addView(Button(this).apply {
            text = "OK"
            setTextColor(Color.BLACK); isAllCaps = false; textSize = 16f
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            background = GradientDrawable().apply { cornerRadius = 24f * scale; setColor(Color.WHITE) }
            layoutParams = LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, (58 * scale).toInt())
            setOnClickListener { removeOverlay() }
        })

        backdrop.addView(card)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM,
            PixelFormat.TRANSLUCENT
        )

        try {
            windowManager?.addView(backdrop, params)
            overlayView = backdrop; overlayShown = true
            card.alpha = 0f; card.scaleX = 0.85f; card.scaleY = 0.85f
            card.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(450).setInterpolator(AccelerateDecelerateInterpolator()).start()
            // Auto-dismiss after 4s so the overlay doesn't linger forever
            // if the user just walks away.
            Handler(Looper.getMainLooper()).postDelayed({ removeOverlay() }, 4000)
        } catch (e: Exception) { overlayShown = false }
    }

    override fun onDestroy() {
        super.onDestroy()
        tickRunnable?.let { handler.removeCallbacks(it) }
        stopLockdownTick()
        removeOverlay()
    }

    override fun onInterrupt() {
        stopLockdownTick()
        lockdownActive = false
        removeOverlay()
    }
}